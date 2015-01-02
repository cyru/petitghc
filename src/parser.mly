%{
    module E = Error

    (* transforms a list of application to the curried form *)
    let list_to_app ((e::es) : Ast.simple_expr list) pos =
        List.fold_left (fun rep e -> Ast.App(rep,e,pos)) (Ast.Single e) es
    
    let fun_to_lambda is e =
        List.fold_right (fun x expr -> Ast.Lambda(x,expr)) is e
%}
%token Eof
%token If Then Else
%token Assign
%token LeftCurly RightCurly LeftBracket RightBracket LeftPar RightPar
%token Plus Minus Time
%token Greater GreaterEq Lower LowerEq Unequal Equal
%token And Or
%token Colon
%token Return
%token Do
%token Case
%token Of
%token True False
%token Comma
%token Lambda
%token Arrow
%token Semicolon
%token Let
%token In
%token <int> Int
%token <string> Ident
%token <string> Ident0
%token <char> Char
%token <string> String

%nonassoc In Lambda
%nonassoc Else
%left Or
%left And
%left Plus Minus
%right Colon
%nonassoc Greater GreaterEq Lower LowerEq Unequal Equal
%left Time
%nonassoc neg

%start <Ast.file> file
%%

file:
    | Eof { [] }
    | d = def0; ds = file { d :: ds }

def0:
    | i = Ident0; is = identList; e = expression { 
        if is = [] then (i,e,($startpos,$endpos)) 
        else ((*i, fun_to_lambda is e,($startpos,$endpos)*)
              (i,Ast.Fun (is,e),($startpos,$endpos)))}
    
def:
    | i = Ident; is = identList; e = expression { 
        if is = [] then (i,e,($startpos,$endpos)) 
        else ((*i, fun_to_lambda is e,($startpos,$endpos)*)
              (i,Ast.Fun (is,e),($startpos,$endpos)))}

simple_expr:
    | LeftPar; e = expression; RightPar { Ast.Par (e,($startpos,$endpos)) }
    | i = Ident                       { Ast.Id (i,($startpos,$endpos)) }
    | c = const                       { Ast.Cst (c,($startpos,$endpos))}
    | LeftBracket; l = eList           { Ast.List (l,($startpos,$endpos)) }

list_simple_expr:
    | s = simple_expr; l = list_simple_expr { s :: l }
    | s = simple_expr { [s] }

eList:
    | e = expression; Comma; l = eList { e :: l }
    | e = expression; RightBracket      { [e] }
    | RightBracket                      { [] }

expression:
    | es = list_simple_expr { list_to_app es ($startpos,$endpos) }
    | Lambda; s = param; e = expression 
        { (*List.fold_right (fun i e -> Ast.Lambda (i,e)) s e*)
          Ast.Fun (s,e) }
    | Minus; e = expression { Ast.Neg (e,($startpos,$endpos)) } %prec neg
    | e1 = expression; Plus; e2 = expression 
        { Ast.BinOp (e1,Ast.Plus,e2,($startpos,$endpos)) }
    | e1 = expression; Minus; e2 = expression 
        { Ast.BinOp (e1,Ast.Minus,e2,($startpos,$endpos)) }
    | e1 = expression; Time; e2 = expression 
        { Ast.BinOp (e1,Ast.Time,e2,($startpos,$endpos)) }
    | e1 = expression; Greater; e2 = expression 
        { Ast.BinOp (e1,Ast.Greater,e2,($startpos,$endpos)) }
    | e1 = expression; GreaterEq; e2 = expression 
        { Ast.BinOp (e1,Ast.GreaterEq,e2,($startpos,$endpos)) }
    | e1 = expression; Lower; e2 = expression 
        { Ast.BinOp (e1,Ast.Lower,e2,($startpos,$endpos)) }
    | e1 = expression; LowerEq; e2 = expression 
        { Ast.BinOp (e1,Ast.LowerEq,e2,($startpos,$endpos)) }
    | e1 = expression; Unequal; e2 = expression 
        { Ast.BinOp (e1,Ast.Unequal,e2,($startpos,$endpos)) }
    | e1 = expression; Equal; e2 = expression 
        { Ast.BinOp (e1,Ast.Equal,e2,($startpos,$endpos)) }
    | e1 = expression; Colon; e2 = expression 
        { Ast.BinOp (e1,Ast.Colon,e2,($startpos,$endpos)) }
    | e1 = expression; Or; e2 = expression 
        { Ast.BinOp (e1,Ast.Or,e2,($startpos,$endpos)) }
    | e1 = expression; And; e2 = expression 
        { Ast.BinOp (e1,Ast.And,e2,($startpos,$endpos)) }
    | If e1 = expression; Then; e2 = expression; Else; e3 = expression 
        { Ast.If (e1,e2,e3,($startpos,$endpos)) }
    | Let; b = bindings; In; e = expression 
        { Ast.Let (b,e,($startpos,$endpos)) }
    | Case e1 = expression Of LeftCurly 
        LeftBracket RightBracket Arrow e2 = expression Semicolon 
        i = Ident Colon is = Ident Arrow e3 = expression Semicolon? RightCurly 
        { Ast.Case (e1,e2,i,is,e3,($startpos,$endpos)) }
    | Do LeftCurly l = toDo 
        { Ast.Do (l,($startpos,$endpos)) }
    | Return LeftPar RightPar 
        { Ast.Return ($startpos,$endpos) }

toDo:
    | d = expression; Semicolon; l = toDo { d :: l }
    | d = expression; Semicolon? RightCurly { d::[] }

identList:
    | i = Ident; l = identList { i :: l }
    | Assign { [] }

param:
    | i = Ident; p = param { i :: p }
    | i = Ident; Arrow { [i] }

bindings:
    | d = def { ([d],($startpos,$endpos)) }
    | LeftCurly; l = listBindings { (l,($startpos,$endpos)) }

listBindings:
    | d = def; Semicolon; l = listBindings { d :: l }
    | d = def; Semicolon? RightCurly { [d] }

const:
    | True          { Ast.True ($startpos,$endpos)    }
    | False         { Ast.False ($startpos,$endpos)    }
    | n = Int       { Ast.Int (n,($startpos,$endpos))      }
    | c = Char      { Ast.Char (c,($startpos,$endpos))    }
    | s = String    { Ast.String (s,($startpos,$endpos))   }
