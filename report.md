## 环境准备

重构后的本地环境需要使用`ocaml 5.2.1`，可以通过2.3.0版本的opam通过以下命令配置本地环境。

```bash
opam switch create 5.2.1
opam install core menhir ocaml-lsp-server odoc ocamlformat utop ppx_deriving core_unix
```

重构版本代码见[Lslightly/stlc](https://github.com/Lslightly/stlc)。

## 实验测试

由于使用了`ocaml 5.2.1`重构了项目，项目管理工具改用`dune`，因此对测试脚本进行了修改。

另外对镜像进行了修改，方便`run_tests.py`使用容器镜像进行测试。执行以下指令创建名为`pldpa`的容器并执行测试。

```bash
docker pull lslightly2357/cs242 # 拉取镜像
docker run -dit --tty --name pldpa --network host lslightly2357/cs242 # 启动容器
python run_tests.py # 执行测试
```

使用`python run_tests.py`进行测试时会执行`solution.sh`。`solution.sh`会调用镜像中的`run.sh`，`run.sh`使用`ocamlrun solution.byte <testcase>`执行答案。

`user.sh`会调用`./_build/default/bin/main.exe`构建好的二进制文件对tests文件进行解析、检查、解释等操作。

`run_tests.py`的改动之处在于使用`dune build`构建项目以及对solution结果的处理。由于docker container使用root用户，`ocamlrun`会输出warning，对答案产生影响，因此需要去除warning。以下是diff结果:

```bash
52c52
<     exec_make = subprocess.check_output("dune build > /dev/null", timeout=300, stderr=subprocess.STDOUT, shell=True)
---
>     exec_make = subprocess.check_output("make > /dev/null", timeout=300, stderr=subprocess.STDOUT, shell=True)
70d69
<         sol = sol.removeprefix("[WARNING] Running as root is not recommended\n") # execute ocamlrun in root user will cause the warning
```

## 实验思路

按照[README.md](README.md)给出的规则编写match匹配语句即可。

### translator

针对let的5条目规则分别编写从`Lang.Pattern`到`IR.Term`的转换。其中变量命名和[RAEDME](README.md)中给出的规则基本一致。

```ocaml
    match (p, t1, t2) with
      | (Lang.Pattern.Wildcard, _, _) -> (*let 1*)
          let t2' = translate_term t2 in t2'
      | (Lang.Pattern.Var(x, xtype), t1, t2) -> (*let 2*)
          let t1' = translate_term t1 in
          let t2' = translate_term t2 in
          IR.Term.App (IR.Term.Lam (x, translate_type xtype, t2'), t1')
      | (Lang.Pattern.Alias(rho, x, xtype), t1, t2)  -> (*let 3*)
          let t1' = translate_term t1 in
          let t' = translate_term (Lang.Term.Let(rho, t1, t2)) in
          IR.Term.App (
            IR.Term.Lam(x, translate_type xtype, t'),
            t1'
          )
      | (Lang.Pattern.Tuple(p1, p2), t1, t2) -> (*let 4*)
          let t' = translate_term (
            Lang.Term.Let(p1, Lang.Term.Project(t1, Left),
              Lang.Term.Let(p2, Lang.Term.Project(t1, Right), t2)
            )
          ) in
          t'
      | (Lang.Pattern.TUnpack(capX, x), t1, t2) -> (*let 5*)
          let t1' = translate_term t1 in
          let t2' = translate_term t2 in
            IR.Term.TUnpack(capX, x, t1', t2')
```

### typechecker

typechecker部分的一些难点在于对`env`和`tenv`的处理。当出现 $\Gamma, x: \tau_1 \vdash t: \tau_2$ 时，需要将 $x: \tau_1$ 将入`env`中(Map.set)。对于 $\Gamma, X \vdash ...$ 的情况，需要将X加入`tenv`中(Set.add)。

### interpreter

interpreter需在每个trystep case处理Err的情况，需要通过`Err e -> Err e`将错误传递给上层。其余按照规则处理即可。

## 实验遇到的困难与解决

配置环境比较困难

需要安装的东西

`opam install core menhir ocaml-lsp-server odoc ocamlformat utop ppx_deriving`

### opam 4.05.0环境配置

除了`opam switch 4.05.0`之外，还需要执行如下命令

```bash
eval `opam config env`
```

### 预处理器ppx以及deriving

需要在`lib/dune`中添加配置

```
(preprocess (pps ppx_sexp_conv))
```

> https://dev.realworldocaml.org/data-serialization.html

### 词法分析器和语法分析器

为了支持lexer需要添加:

```
(ocamllex lexer)
```

> https://mukulrathi.com/create-your-own-programming-language/parsing-ocamllex-menhir/
>
> https://dune.readthedocs.io/en/stable/reference/dune/ocamllex.html


为了支持parser，需要添加:

```
(menhir
  (modules parser)
  (flags --explain --dump)
  (infer true)
)
```

> https://dune.readthedocs.io/en/stable/reference/dune/menhir.html
>
> http://gallium.inria.fr/~fpottier/menhir/manual.html#sec%3Adune

### assert中的`=`定义为`int -> int -> bool`

需要修改`ast.ml`中的`x = x'`为`String.equal x x'`

### `Command.run`在新版本ocaml中已被弃用，需要修改为`Command_unix.run`

`Command.run`已不再使用，需要修改为`Command_unix.run`。需要`opam install core_unix`。

```
let main () =
  let open Command.Let_syntax in
  Command.basic
    ~summary:"Lam2 interpreter"
    [%map_open
      let filename = anon ("filename" %: string) in
      fun () -> run filename
    ]
  |> Command_unix.run
```

> https://discuss.ocaml.org/t/do-you-use-core-or-other-jane-street-libs-tell-us-how/8229/47
>
> https://stackoverflow.com/questions/73364010/core-command-run-api-changed-between-v0-14-and-v0-15/73364842#73364842

### map_open

`map_open`需要安装`ppx_lex`

### `=`的定义可以使用`Stdlib.(=)`实现

typechecker中需要通过如下方式修改`=`定义为`'a -> 'a -> bool`

```ocaml
let (=) = Stdlib.(=)
```

### `Map.add`

`Map.add`会返回`('k, 'v, 'cmp) Map_intf.Map.t Map_intf.Or_duplicate.t`类型，需要修改为使用`Map.set`

### binop规则

$$
\frac{\Gamma \vdash t_1 : \tau \quad \Gamma \vdash t_2: \tau}{\Gamma \vdash t_1 \oplus t_2: \tau}
$$

### solution.byte运行报错

使用4.05.0版本的ocaml对应的`ocamlrun`运行`solution.byte`报以下错误(在本机和)：

```bash
Fatal error: unknown C primitive `bin_prot_blit_buf_string_stub'
```

没有解决，通过重启容器避免这个问题。
