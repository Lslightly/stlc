## 实验遇到的困难与解决

`opam install core menhir ocaml-lsp-server odoc ocamlformat utop ppx_deriving`

配置环境比较困难

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

