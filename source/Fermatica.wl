(* ::Package:: *)

(* ::Title:: *)
(*Fermatica package*)


(* ::Text:: *)
(*Fermatica is a simple interface package between Fermat and Mathematica*)


(* ::Section:: *)
(*Begin*)


BeginPackage["Fermatica`"]


$FermatCMD(*=Environment["FERMATPATH"]*);


$FermatTempDir=$TemporaryDirectory<>"/";


FermatDetachedSession;GetOutput;GetInput;
FermatSession;ParallelFermatSessions;FermatCoroutine;
FDot;
FDotBig;
FPlus;
FInverse;
FTransform;
FDet;
FNormalize;
FKer;
FRowEchelon;
FQuolyMod;
FPolyLeadingTerm;FPolyLeadingOrder;
FGaussSolve;
FTogether;
FCollect;


FLeadingOrder;
FSeries;
FSeriesCoefficient;


$FermaticaHomeDirectory=DirectoryName[$InputFileName];


$FermaticaVersion="1.1";
$FermatVersionString="";


(* ::Subsection::Closed:: *)
(*Missing system tools*)


(* ::Subsubsection::Closed:: *)
(*PartitionWithRemainder*)


System`PartitionWithRemainder::usage="PartitionWithRemainder[list,size] does the same as Partition[list,size], but does not omit the trailing elements if the chunk size does not divide list length.\nE.g. PartitionWithRemainder[{a,b,c,d,e,f,g,h},3] yields {{a,b,c},{d,e,f},{g,h}}.\n Works also for multidimensional arrays.";
System`PartitionWithRemainder=Fold[Replace[#,{}:>Sequence[],{#2}]&,Partition[#1,#2,#2,If[Length[#2]>1,{1,1}&/@#2,{1,1}],{}],Reverse[Length[#2]+Range[Length[#2]]]]&(*(Partition[#1,#2,#2,If[Length[#2]>1,{1,1}&/@#2,{1,1}],{}]//.{}\[RuleDelayed]Sequence[])&;*)


(* ::Section:: *)
(*Private Section*)


Begin["`Private`"]


(* ::Subsection::Closed:: *)
(*Monitors*)


todolist={};
todo[s_String]:=AppendTo[todolist,s];


todo["write *::usage for each command"];


todo["make FGaussSolve work correctly with inhomogeneous equations. Or at least, detect them."]


todo["adjust Fermatica to batch run. Run\[Rule]False option is not sufficient as it does not save the information about the Mathematica names of the variables."];


todo["Prevent printing huge Fermat output at error"];


SetAttributes[CStaticMonitor,{HoldFirst}];
CStaticMonitor[code_,msg_String,delay_:0]:=If[$Notebooks,
Monitor[code,msg,delay],
WriteString["stdout","["<>msg];(WriteString["stdout","]\n"];#)&[code]
];


SetAttributes[CMonitor,{HoldAll}];
CMonitor[code_,mon_,delay_:0,msg_String:""]:=If[$Notebooks,
Monitor[code,mon,delay],
If[msg=!="",WriteString["stdout","["<>msg]];(If[msg=!="",WriteString["stdout","]\n"]];#)&[code]
];


CPrint[ex__]:=If[$Notebooks,Print[ex],WriteString["stdout",#]&/@{ex,"\n"}];
CPrintTemporary[ex__]:=If[$Notebooks,PrintTemporary[ex],WriteString["stdout",#]&/@{"(",ex,")\n"}];


(* ::Input:: *)
(*CWrite[ex__]:=If[!$Notebooks,WriteString["stdout",#]&/@{ex}];*)


CWrite[msg_String]:=If[!$Notebooks,WriteString["stdout",msg]];


CProgress[i_,l_]:=(Which[l-i>10^4,If[Mod[i,10^3]==0,CWrite["M"]],l-i>10^3,If[Mod[i,10^2]==0,CWrite["C"]],l-i>10^2,If[Mod[i,10]==0,CWrite["X"]],True,CWrite["."]]);


SetAttributes[CProgressPrint,HoldFirst];
CProgressPrint[p_Symbol,i_,l_]:=Module[{step=Which[l-p>=10^3,10^3,l-p>=5 10^2,5 10^2,l-p>=10^2,10^2,l-p>=5 10,5 10,l-p>=10,10,l-p>=5,5,True,1],n},
If[Not[TrueQ[p>=0]],CWrite["["<>ToString[l]<>"|"];p=0;];
If[TrueQ[i>=p+step],
n=Quotient[ i-p,step];
p+=n*step;
CWrite["."<>ToString[p]](*CWrite[StringRepeat[RomanNumeral[step],n]]*);
];
If[i>=l,CWrite["]\n"]]
];


(* ::Subsection::Closed:: *)
(*Setting $FermatCMD*)


$FermatCMD/:Set[$FermatCMD,path_String]:=(OwnValues[$FermatCMD]={HoldPattern[$FermatCMD]:>Evaluate[Quiet[Check[fermat=StartProcess[path];WriteString[fermat,"&q\n"];$FermatVersionString=StringTrim[ReadString[fermat,"(c)"]];path,$Failed]]]};CPrint[If[$FermatCMD=!=$Failed,ToString[$FermatCMD]<>":\n"<>$FermatVersionString,Style["Set $FermatCMD to a valid path for fer64.",{Bold}]]];$FermatCMD)


(* ::Subsection::Closed:: *)
(*Greeting*)


(* ::Input:: *)
(*Quiet[Check[fermat=StartProcess[$FermatCMD];WriteString[fermat,"&q\n"];$FermatVersionString=StringTrim[ReadString[fermat,"(c)"]],$FermatCMD=$Failed]];*)


CPrint["\n******************** ",Style["Fermatica v"<>ToString[$FermaticaVersion],{Bold}]," ********************\n\
Inteface to ",Hyperlink["Fermat CAS", "http://home.bway.net/lewis/"],".\n\[Copyright] Roman N. Lee, 2018.\nRead from: "<>$InputFileName<>" (CRC32: "<>ToString[FileHash[$InputFileName,"CRC32"]]<>")"(*,If[$FermatCMD=!=$Failed,ToString[$FermatCMD]<>":\n"<>$FermatVersionString,Style["Set $FermatCMD to a valid path for fer64.",{Bold}]]*)]


$FermatCMD=Environment["FERMATPATH"];


(* ::Subsection::Closed:: *)
(*Matrix functions*)


(* ::Subsubsection::Closed:: *)
(*FDot*)


Options[FDot]={Run->True};


IdentityMatrixQ=#===IdentityMatrix[Length@#]&;


(* ::Text:: *)
(*We remove identity matrices irrespective of their size.*)


FDot[m__?MatrixQ,OptionsPattern[]]:=Module[{
n,
ms={m},
subs,v,
str,fs,
res,
debug},
(*=========================== check input ===========================*)
If[!canmult[Dimensions/@ms],Return[$Failed]];
ms={m};(*debug=First@Timing[ms=DeleteCases[{m},_?IdentityMatrixQ];];
If[debug>10^-2,Print["Removing identity matrices took ",debug]];*)
n=Length@ms;
If[n==1,Return[First@ms]];(*nothing to multiply*)
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,Variables[ms]];
str="
; variables===========================
"<>var2str[Last/@subs]<>"
; matrix===========================
"<>StringRiffle[MapIndexed[mat2str[#1/.subs,"m"<>ToString[First@#2]]&,ms],"\n"]<>"
; command===========================
[m]:="<>StringRiffle["[m"<>ToString[#1]<>"]"&/@Range[n],"*"]<>";
; clean up===========================
@("<>StringRiffle["[m"<>ToString[#1]<>"]"&/@Range[n],","]<>");";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,Run->OptionValue[Run]];
(*=========================== Postprocess ===========================*)
res=Hold[str2mat[fs[#],"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.#2]&[str,(Reverse/@subs)];
If[!TrueQ[OptionValue[Run]],Return[res/.fs->(FermatSession@*ReadString)]];
res=ReleaseHold[res/.fs->Identity];
res
]


(* ::Input:: *)
(*FDot[m1_?MatrixQ,m2_?MatrixQ]:=Module[{*)
(*r1,c1,r2,c2,*)
(*subs=Variables[{m1,m2}],v,i,*)
(*str,t=False,*)
(*res},*)
(*{r1,c1}=Dimensions[m1];*)
(*{r2,c2}=Dimensions[m2];*)
(*(*=========================== check input ===========================*)*)
(*If[c1!=r2,Return[m1 . m2]];*)
(*If[Not[FreeQ[{m1,m2},_Complex]],Print["Sorry, can not treat complex numbers in matrix."];Abort[]];*)
(*(*=========================== fermat input string ===========================*)*)
(*subs=MapIndexed[#->(v@@#2)&,subs];*)
(*str="*)
(*; variables===========================*)
(*"<>var2str[Last/@subs]<>"*)
(*; matrix===========================*)
(*"<>mat2str[m1/.subs,"m1"]<>"*)
(*"<>mat2str[m2/.subs,"m2"]<>"*)
(**)
(*; command===========================*)
(*[m]:=[m1]*[m2];*)
(**)
(*; clean up===========================*)
(*@([m1],[m2]);";*)
(*str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];*)
(*(*=========================== Run through Fermat ===========================*)*)
(*str=FermatSession[str];*)
(*(*=========================== Postprocess ===========================*)*)
(*res=str2mat[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);*)
(*res*)
(*]*)


(* ::Subsubsection::Closed:: *)
(*FDotBig*)


FDotBig::usage="FDotBig[A,B,C,\[Ellipsis]] multiplies the matrices splitting them, if necessary, into blocks. This is to overcome the restriction of Fermat for the ordinary matrices to have not more than 1000000 elements. The block size is given by the option \!\(\*
StyleBox[\"Block\",\nFontWeight->\"Bold\"]\).";


Options[FDotBig]={Block->1000,Monitor->False};


FDotBig[matrices__?MatrixQ,OptionsPattern[]]:=Module[{bmatrices,identity,fdot,sz,i=0,l=0},
sz=OptionValue[Block];
bmatrices=Map[identity,System`PartitionWithRemainder[#,{sz,sz}],{2}]&/@{matrices};
(*dims=Dimensions[#,2]&/@bmatrices;*)
SetAttributes[fdot,Flat];
fdot[a___,b_Plus,c___]:=fdot[a,#,c]&/@b;
If[OptionValue[Monitor],
Monitor[ArrayFlatten[Fold[Inner[(l++;fdot[##])&,##,Plus]&,bmatrices]/.identity->Identity/.fdot->((i++;FDot[##])&)],ToString[i]<>"/"<>ToString[l]]
,ArrayFlatten[Fold[Inner[(l++;fdot),##,Plus]&,bmatrices]/.identity->Identity/.fdot->FDot]]
]


todo["Implement FAddBig in a manner similar to FDotBig."];


(* ::Subsubsection::Closed:: *)
(*FPlus*)


Options[FPlus]={Run->True};


FPlus[m__?MatrixQ,OptionsPattern[]]:=Module[{
n,
ms={m},
subs,v,
str,
res},
(*=========================== check input ===========================*)
n=Length@ms;
If[n==1,Return[ms[[1]]]];(*nothing to multiply*)
If[!SameQ@@(Dimensions/@ms),Return[$Failed]];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,Variables[ms]];
str="
; variables===========================
"<>var2str[Last/@subs]<>"
; matrix===========================
"<>StringRiffle[MapIndexed[mat2str[#1/.subs,"m"<>ToString[First@#2]]&,ms],"\n"]<>"
; command===========================
[m]:="<>StringRiffle["[m"<>ToString[#1]<>"]"&/@Range[n],"+"]<>";
; clean up===========================
@("<>StringRiffle["[m"<>ToString[#1]<>"]"&/@Range[n],","]<>");";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,Run->OptionValue[Run]];
If[!TrueQ[OptionValue[Run]],Return[str]];
(*=========================== Postprocess ===========================*)
res=str2mat[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


(* ::Subsubsection::Closed:: *)
(*FDet*)


Options[FDet]={Run->True};


FDet[m_?SquareMatrixQ,OptionsPattern[]]:=Module[{
l=Length@m,
subs=Variables[m],v,i,
str,
res},
If[Not[FreeQ[m,_Complex]],Print["Sorry, can not treat complex numbers in matrix."];Return[Inverse[m]]];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str="
; variables===========================
"<>var2str[Last/@subs]<>
"
; matrix===========================
"<>mat2str[m/.subs,"m"]<>"

; command===========================
det := Det([m]);

; clean up===========================
@([m]);";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,Run->OptionValue[Run]];
If[!TrueQ[OptionValue[Run]],Return[str]];(*=========================== Postprocess ===========================*)
res=str2scl[str,"det",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


(* ::Subsubsection::Closed:: *)
(*FInverse*)


Options[FInverse]={Run->True};


FInverse[m_?SquareMatrixQ,OptionsPattern[]]:=Module[{
l=Length@m,
subs=Variables[m],v,
str,
res},
(*=========================== check input ===========================*)
If[Not[FreeQ[m,_Complex]],Print["Sorry, can not treat complex numbers in matrix."];Abort[]];
(*=========================== fermat input string ===========================*)
	(*make substitutions*)
subs=MapIndexed[#->(v@@#2)&,subs];
str="
; variables===========================
"<>var2str[Last/@subs]<>
"
; matrix===========================
"<>mat2str[m/.subs,"m"]<>"\[IndentingNewLine]
; command===========================
[mi]:=[m]^-1;

; clean up===========================
@([m]);";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,Run->OptionValue[Run]];
If[!TrueQ[OptionValue[Run]],Return[str]];
(*=========================== Postprocess ===========================*)
res=str2mat[str,"mi",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


FInverse[ms:{__?SquareMatrixQ},OptionsPattern[]]:=Module[{
l,v,subs,sub,strs,str,res},
(*=========================== check input ===========================*)
If[Not[FreeQ[ms,_Complex]],Print["Sorry, can not treat complex numbers in matrix."];Abort[]];
(*=========================== fermat input string ===========================*)
	(*make substitutions*)
{strs,subs}=Transpose[Function[m,
l=Length@m;sub=MapIndexed[#->(v@@#2)&,Variables[m]];str="\n; variables===========================\n"<>var2str[Last/@sub]<>"\n; matrix===========================\n"<>mat2str[m/.sub,"m"]<>"\n\n; command===========================\n[mi]:=[m]^-1;\n\n; clean up===========================\n@([m]);";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
{str,sub}
]/@ms];
(*=========================== Run through Fermat ===========================*)
strs=FermatSession[strs,Run->OptionValue[Run]];
If[!TrueQ[OptionValue[Run]],Return[strs]];
(*=========================== Postprocess ===========================*)
res=MapThread[(str2mat[#,"mi",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@#2))&,{strs,subs}];
res
]


(* ::Subsubsection::Closed:: *)
(*FTransform*)


Options[FTransform]={Run->True};


FTransform[m_?SquareMatrixQ,t_?SquareMatrixQ,x_Symbol:0,OptionsPattern[]]:=Module[{
l=Length[m],
subs=Variables[{m,t}],v,i,
str,
templ,file,
res},
(*=========================== check input ===========================*)
If[l!=Length[t],Message[Dot::dotsh,m,t];Return[$Failed]];
If[Not[FreeQ[{m,t},_Complex]],Print["Sorry, can not treat complex numbers in matrix."];Abort[]];
file=OpenRead[$FermaticaHomeDirectory<>"snippets/FTransform.fer"];
Check[templ=ReadString[file,EndOfFile],Abort[]];
Close[file];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=StringReplace[templ,{"<<vars>>"->var2str[Last/@subs],"<<l>>"->ToString[l],"<<M>>"->imat2str[m/.subs],"<<T>>"->imat2str[t/.subs],"<<x>>"->ToString[x/.subs]}];
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,Run->OptionValue[Run]];
If[!TrueQ[OptionValue[Run]],Return[str]];
(*=========================== Postprocess ===========================*)
res=str2mat[str,"mt",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


(* ::Subsubsection::Closed:: *)
(*FQuolyMod*)


Options[FQuolyMod]={Run->True};


FQuolyMod[quoly_,poly_,x_Symbol,OptionsPattern[]]:=Module[{
subs=Append[DeleteCases[Variables[{quoly,poly}],x],x],
v,i,
str,
templ,file,
res},
(*=========================== check input ===========================*)
If[Not[FreeQ[{quoly,poly},_Complex]],Print["Sorry, can not treat complex numbers."];Abort[]];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=var2str[Last/@subs]<>"
quoly := "<>ToString[quoly/.subs,InputForm]<>";
poly := "<>ToString[poly/.subs,InputForm]<>";
quoly := QuolyMod(quoly,poly);";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/ModTools.lib.fer"},Run->OptionValue[Run]];
If[!OptionValue[Run],Return[str]];
(*=========================== Postprocess ===========================*)
res=str2scl[str,"quoly",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


FQuolyMod[m_?MatrixQ,poly_,x_Symbol,OptionsPattern[]]:=Module[{
r,c,
subs=Append[DeleteCases[Variables[{m,poly}],x],x],
v,i,
str,
templ,file,
res,mon=0},
{r,c}=Dimensions[m];
(*=========================== check input ===========================*)
If[Not[FreeQ[{m,poly},_Complex]],Print["Sorry, can not treat complex numbers."];Abort[]];
file=OpenRead[$FermaticaHomeDirectory<>"snippets/FQuolyMod.fer"];
Check[templ="\n\n"<>ReadString[file,EndOfFile],Abort[]];
Close[file];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=StringReplace[templ,{"<<vars>>"->var2str[Last/@subs],"<<r>>"->ToString[r],"<<c>>"->ToString[c],"<<M>>"->imat2str[m/.subs],"<<poly>>"->ToString[poly/.subs,InputForm]}];
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
(*CMonitor[code_,mon_,delay_:0,msg_String:""]*)
CMonitor[str=FermatSession[str,mon,Which[StringMatchQ[#2,"QuolyMod*"],#1+1,True,#1]&,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/ModTools.lib.fer"},Run->OptionValue[Run]],ProgressIndicator[mon,{0,r}],1,"QuolyModding..."];
(*=========================== Postprocess ===========================*)
If[!TrueQ[OptionValue[Run]],Return[str]];res=str2mat[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


FQuolyMod[ex_,x_Symbol->poly_,opts:OptionsPattern[]]:=FQuolyMod[ex,poly,x,opts]
FQuolyMod[ex_,list_List,opts:OptionsPattern[]]:=Fold[FQuolyMod[#1,#2,opts]&,ex,list]


(* ::Subsubsection::Closed:: *)
(*FSeries*)


Options[FSeries]={Run->True(*,Normal\[Rule]True*)};


FSeries[quoly:Except[_List],{x_Symbol,x0_,o_Integer},OptionsPattern[]]:=Module[{
subs=Append[DeleteCases[Variables[{quoly,x0}],x],x],
v,i,
str,
templ,
coefs,lo,
res},
(*=========================== check input ===========================*)
If[Not[FreeQ[{quoly},_Complex]],Print["Sorry, can not treat complex numbers."];Abort[]];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=var2str[Last/@subs]<>"
quoly := "<>ToString[quoly/.subs,InputForm]<>";
Series(quoly, "<>ToString[x/.subs,InputForm]<>", "<>ToString[x0/.subs,InputForm]<>", "<>ToString[o,InputForm]<>");";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/FSeries.lib.fer"},Run->OptionValue[Run]];
If[!OptionValue[Run],Return[str]];
(*=========================== Postprocess ===========================*)
coefs=str2lst[str,"cSeries",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
lo=str2scl[str,"oSeries",{}];
res=SeriesData[x,x0,coefs,lo,lo+Length[coefs],1];
res
]


FSeries[m_?MatrixQ,{x_Symbol,x0_,o_Integer},OptionsPattern[]]:=Module[{
r,c,
subs=Append[DeleteCases[Variables[{m,x0}],x],x],
v,i,
str,
templ,file,
res,mon=0},
{r,c}=Dimensions[m];
(*=========================== check input ===========================*)
file=OpenRead[$FermaticaHomeDirectory<>"snippets/FSeries.fer"];
Check[templ="\n\n"<>ReadString[file,EndOfFile],Abort[]];
Close[file];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=StringReplace[templ,{"<<vars>>"->var2str[Last/@subs],"<<var>>"->ToString[x/.subs,InputForm],"<<var0>>"->ToString[x0/.subs,InputForm],"<<r>>"->ToString[r],"<<c>>"->ToString[c],"<<M>>"->imat2str[m/.subs],"<<order>>"->ToString[o,InputForm]}];
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
(*CMonitor[code_,mon_,delay_:0,msg_String:""]*)
CMonitor[str=FermatSession[str,mon,Which[StringMatchQ[#2,"Series*"],#1+1,True,#1]&,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/FSeries.lib.fer"},Run->OptionValue[Run]],ProgressIndicator[mon,{0,r}],1,"FSeries..."];
(*=========================== Postprocess ===========================*)
If[!TrueQ[OptionValue[Run]],Return[str]];res=str2mat[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res+Series[x-x0,{x,x0,0}]*(x-x0)^o
]


(* ::Subsubsection::Closed:: *)
(*FLeadingOrder*)


Options[FLeadingOrder]={Run->True(*,Normal\[Rule]True*)};


FLeadingOrder[quoly:Except[_List],{x_Symbol,x0:Except[Infinity]},OptionsPattern[]]:=Module[{
subs=Append[DeleteCases[Variables[{quoly,x0}],x],x],
v,i,
str,
res},
(*=========================== check input ===========================*)
If[Not[FreeQ[{quoly},_Complex]],Print["Sorry, can not treat complex numbers."];Abort[]];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=var2str[Last/@subs]<>"
quoly := "<>ToString[quoly/.subs,InputForm]<>";
lorder := LOrder(quoly, "<>ToString[x/.subs,InputForm]<>", "<>ToString[x0/.subs,InputForm]<>");";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/FSeries.lib.fer"},Run->OptionValue[Run]];
If[!OptionValue[Run],Return[str]];
(*=========================== Postprocess ===========================*)
res=str2scl[str,"lorder",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


FLeadingOrder[m_?MatrixQ,{x_Symbol,x0:Except[Infinity]},OptionsPattern[]]:=Module[{
r,c,
subs=Append[DeleteCases[Variables[{m,x0}],x],x],
v,i,
str,
templ,file,
res,mon=0},
{r,c}=Dimensions[m];
(*=========================== check input ===========================*)
file=OpenRead[$FermaticaHomeDirectory<>"snippets/FLeadingOrder.fer"];
Check[templ="\n\n"<>ReadString[file,EndOfFile],Abort[]];
Close[file];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=StringReplace[templ,{"<<vars>>"->var2str[Last/@subs],"<<var>>"->ToString[x/.subs,InputForm],"<<var0>>"->ToString[x0/.subs,InputForm],"<<r>>"->ToString[r],"<<c>>"->ToString[c],"<<M>>"->imat2str[m/.subs]}];
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
(*CMonitor[code_,mon_,delay_:0,msg_String:""]*)
CMonitor[str=FermatSession[str,mon,Which[StringMatchQ[#2,"LOrder*"],#1+1,True,#1]&,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/FSeries.lib.fer"},Run->OptionValue[Run]],ProgressIndicator[mon,{0,r}],1,"FLeadingOrder..."];
(*=========================== Postprocess ===========================*)
If[!TrueQ[OptionValue[Run]],Return[str]];res=str2scl[str,"lorder",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}];
res
]


FLeadingOrder[vec_?VectorQ,{x_Symbol,x0_},opts:OptionsPattern[]]:=FLeadingOrder[{vec},{x,x0},opts]


FLeadingOrder[quoly_,{x_Symbol,Infinity},opts:OptionsPattern[]]:=FLeadingOrder[quoly/.x->1/x,{x,0},opts]


(* ::Subsubsection::Closed:: *)
(*FSeriesCoefficient*)


Options[FSeriesCoefficient]={Run->True(*,Normal\[Rule]True*)};


(* ::Input:: *)
(*FSeriesCoefficient[quoly:Except[_List],{x_Symbol,x0:Except[Infinity],o_Integer},OptionsPattern[]]*)


FSeriesCoefficient[quoly:Except[_List],{x_Symbol,x0:Except[Infinity],o_Integer},OptionsPattern[]]:=Module[{
subs=Append[DeleteCases[Variables[{quoly}],x],x],
v,i,
str,
templ,
coefs,lo,
res},
(*=========================== check input ===========================*)
If[Not[FreeQ[{quoly},_Complex]],Print["Sorry, can not treat complex numbers."];Abort[]];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=var2str[Last/@subs]<>"
quoly := "<>ToString[quoly/.subs,InputForm]<>";
coef:=SerCoef(quoly, "<>ToString[x/.subs,InputForm]<>", "<>ToString[x0/.subs,InputForm]<>", "<>ToString[o,InputForm]<>");";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/FSeries.lib.fer"},Run->OptionValue[Run]];
If[!OptionValue[Run],Return[str]];
(*=========================== Postprocess ===========================*)
res=str2scl[str,"coef",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


FSeriesCoefficient[m_?MatrixQ,{x_Symbol,x0:Except[Infinity],o_Integer},OptionsPattern[]]:=Module[{
r,c,
subs=Append[DeleteCases[Variables[{m,x0}],x],x],
v,i,
str,
templ,file,
res,mon=0},
{r,c}=Dimensions[m];
(*=========================== check input ===========================*)
file=OpenRead[$FermaticaHomeDirectory<>"snippets/FSeriesCoefficient.fer"];
Check[templ="\n\n"<>ReadString[file,EndOfFile],Abort[]];
Close[file];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=StringReplace[templ,{"<<vars>>"->var2str[Last/@subs],"<<var>>"->ToString[x/.subs,InputForm],"<<var0>>"->ToString[x0/.subs,InputForm],"<<r>>"->ToString[r],"<<c>>"->ToString[c],"<<M>>"->imat2str[m/.subs],"<<order>>"->ToString[o,InputForm]}];
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
(*CMonitor[code_,mon_,delay_:0,msg_String:""]*)
CMonitor[str=FermatSession[str,mon,Which[StringMatchQ[#2,"Series*"],#1+1,True,#1]&,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/FSeries.lib.fer"},Run->OptionValue[Run]],ProgressIndicator[mon,{0,r}],1,"FSeries..."];
(*=========================== Postprocess ===========================*)
If[!TrueQ[OptionValue[Run]],Return[str]];res=str2mat[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


(* ::Subsubsection::Closed:: *)
(*FPolyLeadingTerm*)


todo["Redefine FPolyLeadingTerm for matrices."];


FPolyLeadingTerm::usage="FPolyLeadingTerm[\!\(\*
StyleBox[\"Q\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\),\!\(\*
StyleBox[\"P\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\),\!\(\*
StyleBox[\"x\", \"TI\"]\)] gives the result of the form \!\(\*
StyleBox[\"P\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*SuperscriptBox[
StyleBox[\")\", \"TI\"], \(k\)]\)\!\(\*
StyleBox[\"R\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\), where \!\(\*
StyleBox[\"k\", \"TI\"]\) is the \"leading order\" and \!\(\*
StyleBox[\"R\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\) is the \"remainder\", such that \!\(\*
StyleBox[\"Q\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\)\!\(\*
StyleBox[\"=\", \"TI\"]\)\!\(\*
StyleBox[\"P\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*SuperscriptBox[
StyleBox[\")\", \"TI\"], \(k\)]\)(\!\(\*
StyleBox[\"R\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\)\!\(\*
StyleBox[\"+\", \"TI\"]\)\!\(\*
StyleBox[\" \", \"TI\"]\)\!\(\*
StyleBox[\"P\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\)\!\(\*
StyleBox[\"\[CenterDot]\", \"TI\"]\)\!\(\*
StyleBox[\"S\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\), where \!\(\*
StyleBox[\"S\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\) is a rational function with denominator being mutually simple with \!\(\*
StyleBox[\"P\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\).";


Options[FPolyLeadingTerm]={Run->True};


FPolyLeadingTerm[quoly_,poly_,x_Symbol,OptionsPattern[]]:=Module[{
subs=Append[DeleteCases[Variables[{quoly,poly}],x],x],
v,i,
str,
templ,file,
res},
(*=========================== check input ===========================*)
If[Not[FreeQ[{quoly,poly},_Complex]],Print["Sorry, can not treat complex numbers."];Abort[]];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=var2str[Last/@subs]<>"
quoly := "<>ToString[quoly/.subs,InputForm]<>";
poly := "<>ToString[poly/.subs,InputForm]<>";
quoly := LQMTerm(quoly,poly);";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/ModTools.lib.fer"},Run->OptionValue[Run]];
If[!OptionValue[Run],Return[str]];
(*=========================== Postprocess ===========================*)
res=str2scl[str,"quoly",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


FPolyLeadingTerm[m_?MatrixQ,poly_,x_Symbol,OptionsPattern[]]:=Module[{
r,c,
subs=Append[DeleteCases[Variables[{m,poly}],x],x],
v,i,
str,
templ,file,
res},
{r,c}=Dimensions[m];
(*=========================== check input ===========================*)
If[Not[FreeQ[{m,poly},_Complex]],Print["Sorry, can not treat complex numbers."];Abort[]];
file=OpenRead[$FermaticaHomeDirectory<>"snippets/FPolyLeadingTerm.fer"];
Check[templ="\n\n"<>ReadString[file,EndOfFile],Abort[]];
Close[file];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=StringReplace[templ,{"<<vars>>"->var2str[Last/@subs],"<<r>>"->ToString[r],"<<c>>"->ToString[c],"<<M>>"->imat2str[m/.subs],"<<poly>>"->ToString[poly/.subs,InputForm]}];
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/ModTools.lib.fer"},Run->OptionValue[Run]];
(*=========================== Postprocess ===========================*)
If[!TrueQ[OptionValue[Run]],Return[str]];res=str2mat[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


(* ::Subsubsection::Closed:: *)
(*FPolyLeadingOrder*)


FPolyLeadingOrder::usage="FPolyLeadingOrder[\!\(\*
StyleBox[\"Q\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\),\!\(\*
StyleBox[\"P\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\),\!\(\*
StyleBox[\"x\", \"TI\"]\)] gives the \"leading order\"  \!\(\*
StyleBox[\"k\", \"TI\"]\) such that, \!\(\*
StyleBox[\"Q\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\)\!\(\*
StyleBox[\"=\", \"TI\"]\)\!\(\*
StyleBox[\"P\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*SuperscriptBox[
StyleBox[\")\", \"TI\"], \(k\)]\)\!\(\*
StyleBox[\"S\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\), where both the numerator and denominator of \!\(\*
StyleBox[\"S\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\) are mutually simple with \!\(\*
StyleBox[\"P\", \"TI\"]\)\!\(\*
StyleBox[\"(\", \"TI\"]\)\!\(\*
StyleBox[\"x\", \"TI\"]\)\!\(\*
StyleBox[\")\", \"TI\"]\).";


Options[FPolyLeadingOrder]={Run->True};


FPolyLeadingOrder[quoly_,poly_,x_Symbol,OptionsPattern[]]:=Module[{
subs=Append[DeleteCases[Variables[{quoly,poly}],x],x],
v,i,
str,
templ,file,
res},
(*=========================== check input ===========================*)
If[Not[FreeQ[{quoly,poly},_Complex]],Print["Sorry, can not treat complex numbers."];Abort[]];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=var2str[Last/@subs]<>"
quoly := "<>ToString[quoly/.subs,InputForm]<>";
poly := "<>ToString[poly/.subs,InputForm]<>";
quoly := LQMOrder(quoly,poly);";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/ModTools.lib.fer"},Run->OptionValue[Run]];
If[!OptionValue[Run],Return[str]];
(*=========================== Postprocess ===========================*)
res=str2scl[str,"quoly",{"infty":>"Infinity","v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


FPolyLeadingOrder[m_?MatrixQ,poly_,x_Symbol,OptionsPattern[]]:=Module[{
r,c,
subs=Append[DeleteCases[Variables[{m,poly}],x],x],
v,i,
str,
templ,file,
res},
{r,c}=Dimensions[m];
(*=========================== check input ===========================*)
If[Not[FreeQ[{m,poly},_Complex]],Print["Sorry, can not treat complex numbers."];Abort[]];
file=OpenRead[$FermaticaHomeDirectory<>"snippets/FPolyLeadingOrder.fer"];
Check[templ="\n\n"<>ReadString[file,EndOfFile],Abort[]];
Close[file];
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=StringReplace[templ,{"<<vars>>"->var2str[Last/@subs],"<<r>>"->ToString[r],"<<c>>"->ToString[c],"<<M>>"->imat2str[m/.subs],"<<poly>>"->ToString[poly/.subs,InputForm]}];
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,LibraryLoad->{$FermaticaHomeDirectory<>"snippets/ModTools.lib.fer"},Run->OptionValue[Run]];
(*=========================== Postprocess ===========================*)
If[!TrueQ[OptionValue[Run]],Return[str]];res=str2scl[str,"k",{"infty":>"Infinity","v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
res
]


(* ::Subsubsection::Closed:: *)
(*FNormalize*)


Options[FNormalize]={Run->True};


FNormalize[m_?SquareMatrixQ,OptionsPattern[]]:=Module[{
l=Length@m,
subs=Variables[m],v,
str,
a,b,c,d,r},
If[Not[FreeQ[m,_Complex]],Print["Sorry, can not treat complex numbers in matrix."];Return[Inverse[m]]];
(*=========================== Write input file ===========================*)
	(*make substitutions*)
subs=MapIndexed[#->(v@@#2)&,subs];
str="
; variables===========================
"<>var2str[Last/@subs]<>"

; matrix===========================
"<>mat2str[m/.subs,"m"]<>"

; command===========================
Normalize([m],[a],[b],[c],[d]);

; clean up===========================
";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,Run->OptionValue[Run]];
If[!TrueQ[OptionValue[Run]],Return[str]];
(*=========================== Postprocess ===========================*)
r=str2mat[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
a=str2mat[str,"a",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
b=str2mat[str,"b",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
c=str2mat[str,"c",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
d=str2mat[str,"d",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
{a,b,c,d,r}
]


todo["inplement Colreduce similarly to Normalize"];


(* ::Subsubsection::Closed:: *)
(*FKer*)


(* ::Text:: *)
(*list of basis vectors of the kernel*)


Options[FKer]={Run->True};


FKer[m_?MatrixQ,OptionsPattern[]]:=Module[{
r,c,
subs=Variables[m],v,
str,
templ,file,
res},
{r,c}=Dimensions[m];
If[Not[FreeQ[m,_Complex]],Print["Sorry, can not treat complex numbers in matrix."];Abort[]];
file=OpenRead[$FermaticaHomeDirectory<>"snippets/FKer.fer"];
Check[templ=ReadString[file,EndOfFile],Abort[]];
Close[file];
(*=========================== Write input file ===========================*)
	(*make substitutions*)
subs=MapIndexed[#->(v@@#2)&,subs];
str=StringReplace[StringReplace[templ,{"<<vars>>"->var2str[Last/@subs],"<<rows>>"->ToString[r],"<<cols>>"->ToString[c],"<<matr>>"->imat2str[m/.subs]}],(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,Run->OptionValue[Run]];
If[!TrueQ[OptionValue[Run]],Return[str]];
(*=========================== Postprocess ===========================*)res=str2mat[str,"ns",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);
Transpose[res]
]


(* ::Subsubsection::Closed:: *)
(*FRowEchelon*)


FRowEchelon::usage ="FRowEchelon[\!\(\*
StyleBox[\"m\", \"TI\"]\)] gives the row-reduced form of the matrix \!\(\*
StyleBox[\"m\", \"TI\"]\).";


Options[FRowEchelon]={Run->True,Reduce->False};
FRowEchelon[m_?MatrixQ,OptionsPattern[]]:=Module[{
mt,vs,
v,subs,
str,res,
monbuf,monpr=0,monl=1,monf,monr=False,mont},
monf=If[monr,mont=StringCases[#3,x:(DigitCharacter..):>ToExpression[x]];If[mont=!={},monpr=Last@mont];"",
If[MatchQ[{#1,#3},{_String,_String}],mont=StringCases[#3,"Sparse reduce row echelon, cols "~~(x:DigitCharacter..):>ToExpression[x]];
If[mont=!={},monl=Last@mont;monr=True];#1<>#3,#1]]&;
mt=ArrayRules[m];
vs=Variables[Last/@mt];
subs=MapIndexed[#->(v@@#2)&,vs];
str="
; variables =========================
"<>var2str[Last/@subs]<>
"
; matrix ============================
"<>smat2str[SparseArray[mt/.subs,Dimensions[m]],"m"]<>"
; turn on dislay====================
&V;
; command ===========================
R"<>If[OptionValue[Reduce],"edr",""]<>"owech([m]);";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
monbuf="";
Monitor[
str=FermatSession[str,monbuf,monf,Run->OptionValue[Run]],
ProgressIndicator[monpr,{0,monl}]];
If[!TrueQ[OptionValue[Run]],Return[str]];
(*=========================== Postprocess ===========================*)
res=SparseArray[Flatten[Function[row,{row[[1]],#1}->#2&@@@Rest[row]]/@str2sarr[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs)],Dimensions@m];
res
]


(* ::Subsubsection::Closed:: *)
(*FGaussSolve*)


FGaussSolve::usage ="FGaussSolve[eqs,vars] solves homogeneous linear equations.";
FGaussSolve::notimplemented ="Sorry, not implemented. Aborting...";


FGaussSolve::inconsistent="Inconsistent equation encountered.";


Options[FGaussSolve]={Run->True,Reduce->True};
FGaussSolve[eqs_,vars_,OptionsPattern[]]:=Module[{
eqsn,i,m,rvars,u=0,
v,subs,
str,res,
monbuf,monpr=0,monpr1=-1,monl=1,monf,monr=False,mont},
If[eqs==={},Return[{}]];
monf=If[monr,mont=StringCases[#3,x:(DigitCharacter..):>ToExpression[x]];If[mont=!={},monpr=Last@mont;CProgressPrint[monpr1,monpr,monl]];"",
If[MatchQ[{#1,#3},{_String,_String}],mont=StringCases[#3,"Sparse reduce row echelon, cols "~~(x:DigitCharacter..):>ToExpression[x]];
If[mont=!={},monl=Last@mont;monr=True];#1<>#3,#1]]&;
rvars=Append[Reverse[vars],i];
eqsn=eqs-(eqs/.Dispatch[Thread[vars->0]])(1-i);
(*m=Outer[Coefficient,eqsn,rvars];*)
m=CoefficientArrays[eqsn,rvars];
(*=========================== check input ===========================*)
If[Not[FreeQ[m,_Complex]],Message[FGaussSolve::notimplemented];Abort[]];
If[Length[m]=!=2,Message[FGaussSolve::notimplemented];Abort[]];
If[Length[ArrayRules[First[m]]]>1,
Message[FGaussSolve::notimplemented];Abort[]];
(*=========================== fermat input string ===========================*)
	(*make substitutions*)
m=ArrayRules[Last[m]];
subs=MapIndexed[#->(v@@#2)&,Variables[Last/@m]];
(*CPrint["Pivoting: &(u="<>ToString[u]<>");"];*)
str="
; variables =========================
"<>var2str[Last/@subs]<>
"
; matrix ============================
"<>smat2str[SparseArray[m/.subs,{Length@eqs,Length@rvars}],"m"]<>"
; turn on dislay====================
&V;
; choose pivoting strategy
&(u="<>ToString[u]<>");
; command ===========================
R"<>If[OptionValue[Reduce],"edr",""]<>"owech([m]);";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
monbuf="";monl=Length@rvars;
CMonitor[
str=FermatSession[str,monbuf,monf,Run->OptionValue[Run]],
Overlay[{ProgressIndicator[monpr,{0,monl}],"GS:"<>ToString[monpr]<>"/"<>ToString[monl]},Alignment->Center],1];
If[!TrueQ[OptionValue[Run]],Return[str]];
(*=========================== Postprocess ===========================*)
res=First[#][[1]]->-1/First[#][[2]] Plus@@Times@@@Rest[#]&/@
MapAt[rvars[[#]]&,(Rest/@str2sarr[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs)),{All,All,1}];
If[MemberQ[res,i->_],Message[FGaussSolve::inconsistent]];
Return[DeleteCases[res,i->_]/.i->1]
]


(* ::Input:: *)
(*Options[FGaussSolve]={Run->True,Reduce->True};*)
(*FGaussSolve[eqs_,vars_,OptionsPattern[]]:=Module[{*)
(*m,rvars=Reverse[vars],u=0,*)
(*v,subs,*)
(*str,res,*)
(*monbuf,monpr=0,monpr1=-1,monl=1,monf,monr=False,mont},*)
(*If[eqs==={},Return[{}]];*)
(*monf=If[monr,mont=StringCases[#3,x:(DigitCharacter..):>ToExpression[x]];If[mont=!={},monpr=Last@mont;CProgressPrint[monpr1,monpr,monl]];"",*)
(*If[MatchQ[{#1,#3},{_String,_String}],mont=StringCases[#3,"Sparse reduce row echelon, cols "~~(x:DigitCharacter..):>ToExpression[x]];*)
(*If[mont=!={},monl=Last@mont;monr=True];#1<>#3,#1]]&;*)
(*m=CoefficientArrays[eqs,rvars];*)
(*(*=========================== check input ===========================*)*)
(*If[Not[FreeQ[m,_Complex]],Message[FGaussSolve::notimplemented];Abort[]];*)
(*If[Length[m]=!=2,Message[FGaussSolve::notimplemented];Abort[]];*)
(*If[Length[ArrayRules[First[m]]]>1,*)
(*Message[FGaussSolve::notimplemented];Abort[]];*)
(*(*=========================== fermat input string ===========================*)*)
(*	(*make substitutions*)*)
(*m=ArrayRules[Last[m]];*)
(*subs=MapIndexed[#->(v@@#2)&,Variables[Last/@m]];*)
(*(*CPrint["Pivoting: &(u="<>ToString[u]<>");"];*)*)
(*str="*)
(*; variables =========================*)
(*"<>var2str[Last/@subs]<>*)
(*"*)
(*; matrix ============================*)
(*"<>smat2str[SparseArray[m/.subs,{Length@eqs,Length@vars}],"m"]<>"*)
(*; turn on dislay====================*)
(*&V;*)
(*; choose pivoting strategy*)
(*&(u="<>ToString[u]<>");*)
(*; command ===========================*)
(*R"<>If[OptionValue[Reduce],"edr",""]<>"owech([m]);";*)
(*str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];*)
(*(*=========================== Run through Fermat ===========================*)*)
(*monbuf="";monl=Length@vars;*)
(*CMonitor[*)
(*str=FermatSession[str,monbuf,monf,Run->OptionValue[Run]],*)
(*Overlay[{ProgressIndicator[monpr,{0,monl}],"GS:"<>ToString[monpr]<>"/"<>ToString[monl]},Alignment->Center],1];*)
(*If[!TrueQ[OptionValue[Run]],Return[str]];*)
(*(*=========================== Postprocess ===========================*)*)
(*res=First[#][[1]]->-1/First[#][[2]] Plus@@Times@@@Rest[#]&/@*)
(*MapAt[rvars[[#]]&,(Rest/@str2sarr[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs)),{All,All,1}];*)
(*res*)
(*]*)


(* ::Subsubsection::Closed:: *)
(*FTogether*)


Options[FTogether]={Run->True};


FTogether::usage="FTogether[m_?MatrixQ] simply reads in the matrix and writes back. Since Fermat automatically makes \"Together\" we have what we want."


FTogether[sd_SeriesData,opts:OptionsPattern[]]:=MapAt[FTogether[#,opts]&,sd,{3}];


FTogether[{},OptionsPattern[]]:={}
FTogether[s:Except[_List],opts:OptionsPattern[]]:=FTogether[{{s}},opts][[1,1]]
FTogether[v_?VectorQ,opts:OptionsPattern[]]:=First[FTogether[{v},opts]]


FTogether[m_?MatrixQ,OptionsPattern[]]:=Module[{
subs,v,
str,fs,
res},
(*=========================== check input ===========================*)
(*=========================== fermat input string ===========================*)
subs=MapIndexed[#->(v@@#2)&,Variables[m]];
str="
; variables===========================
"<>var2str[Last/@subs]<>"
; matrix===========================
"<>mat2str[m/.subs,"m"]<>"
;";
str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];
(*=========================== Run through Fermat ===========================*)
str=FermatSession[str,Run->OptionValue[Run]];
(*=========================== Postprocess ===========================*)
res=Hold[str2mat[fs[#],"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.#2]&[str,(Reverse/@subs)];
If[!TrueQ[OptionValue[Run]],Return[res/.fs->(FermatSession@*ReadString)]];
res=ReleaseHold[res/.fs->Identity];
res
]


(* ::Input:: *)
(*FDot[m1_?MatrixQ,m2_?MatrixQ]:=Module[{*)
(*r1,c1,r2,c2,*)
(*subs=Variables[{m1,m2}],v,i,*)
(*str,t=False,*)
(*res},*)
(*{r1,c1}=Dimensions[m1];*)
(*{r2,c2}=Dimensions[m2];*)
(*(*=========================== check input ===========================*)*)
(*If[c1!=r2,Return[m1 . m2]];*)
(*If[Not[FreeQ[{m1,m2},_Complex]],Print["Sorry, can not treat complex numbers in matrix."];Abort[]];*)
(*(*=========================== fermat input string ===========================*)*)
(*subs=MapIndexed[#->(v@@#2)&,subs];*)
(*str="*)
(*; variables===========================*)
(*"<>var2str[Last/@subs]<>"*)
(*; matrix===========================*)
(*"<>mat2str[m1/.subs,"m1"]<>"*)
(*"<>mat2str[m2/.subs,"m2"]<>"*)
(**)
(*; command===========================*)
(*[m]:=[m1]*[m2];*)
(**)
(*; clean up===========================*)
(*@([m1],[m2]);";*)
(*str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];*)
(*(*=========================== Run through Fermat ===========================*)*)
(*str=FermatSession[str];*)
(*(*=========================== Postprocess ===========================*)*)
(*res=str2mat[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);*)
(*res*)
(*]*)


(* ::Subsubsection::Closed:: *)
(*FCollect*)


FCollect::usage="FCollect[\[Ellipsis]] simply reads in the matrix and writes back. Since Fermat automatically makes \"Together\" we have what we want."


FCollect[expr_,pat_]:=Module[{cs={},cdefs={},res},
res=Collect[expr,pat,
Function[coef,
(AppendTo[cs,#];AppendTo[cdefs,coef];#)&[Unique["c"]]
]
]/.Dispatch[Thread[cs->FTogether[cdefs]]];
Remove/@cs;
res
]


(* ::Input:: *)
(*FDot[m1_?MatrixQ,m2_?MatrixQ]:=Module[{*)
(*r1,c1,r2,c2,*)
(*subs=Variables[{m1,m2}],v,i,*)
(*str,t=False,*)
(*res},*)
(*{r1,c1}=Dimensions[m1];*)
(*{r2,c2}=Dimensions[m2];*)
(*(*=========================== check input ===========================*)*)
(*If[c1!=r2,Return[m1 . m2]];*)
(*If[Not[FreeQ[{m1,m2},_Complex]],Print["Sorry, can not treat complex numbers in matrix."];Abort[]];*)
(*(*=========================== fermat input string ===========================*)*)
(*subs=MapIndexed[#->(v@@#2)&,subs];*)
(*str="*)
(*; variables===========================*)
(*"<>var2str[Last/@subs]<>"*)
(*; matrix===========================*)
(*"<>mat2str[m1/.subs,"m1"]<>"*)
(*"<>mat2str[m2/.subs,"m2"]<>"*)
(**)
(*; command===========================*)
(*[m]:=[m1]*[m2];*)
(**)
(*; clean up===========================*)
(*@([m1],[m2]);";*)
(*str=StringReplace[str,(ToString[v]<>"[")~~(n:DigitCharacter..)~~"]":>"v"<>n];*)
(*(*=========================== Run through Fermat ===========================*)*)
(*str=FermatSession[str];*)
(*(*=========================== Postprocess ===========================*)*)
(*res=str2mat[str,"m",{"v"~~(n:DigitCharacter..):>(ToString[v]<>"[")<>n<>"]"}]/.(Reverse/@subs);*)
(*res*)
(*]*)


(* ::Subsection:: *)
(*Fermat Sessions*)


(* ::Subsubsection:: *)
(*FermatSession*)


FermatSession::fail="Something went wrong when invoking fermat with \"`1`\". Setting variable $FermatCMD to different value might help.";


FermatSession::cmd="To use Fermat CAS, set $FermatCMD to the fermat executable full path with\n    $FermatCMD=\"path/to/fer64\";\nAlternatively, you may set the system environment variable FERMATPATH to the same path.";


todo["check that FermatSession works better (changed termination criterion)"];


FermatSession::switches="&_t;";


SetAttributes[FermatSession,HoldRest];


Options[FermatSession]:={
Run->True,
Background->False,(*whether to run in Background*)
DeleteFile->True,
In->Automatic,
Out->Automatic,
LibraryLoad->{}
};


Module[{dummy},
FermatSession[str_String,monitor_Symbol:dummy,mfunc:Except[_Rule|_RuleDelayed]:(#2&),opts:OptionsPattern[]]:=
Module[
{in,out,res,delay},
If[!MatchQ[$FermatCMD,_String],Message[FermatSession::cmd];Return[$Failed]];
{in,out}=PrepareInOut[str,FilterRules[{opts},Options[PrepareInOut]]];
If[!OptionValue[Run],Return[{in,out}]];
ParallelRun[{{in,out}},{monitor},mfunc[#1,#2,#3]&];
If[OptionValue[DeleteFile],
res=ReadString[out,EndOfFile];DeleteFile[{in,out}],
res=out;DeleteFile[in];
];
res
];
FermatSession[strs:{__String},monitor_Symbol:dummy,mfunc:Except[_Rule|_RuleDelayed]:(#2&),opts:OptionsPattern[]]:=
Module[
{inouts,res,delay},
If[!MatchQ[$FermatCMD,_String],Message[FermatSession::cmd];Return[$Failed]];
inouts=PrepareInOut[#,FilterRules[{opts},Options[PrepareInOut]]]&/@strs;
If[!OptionValue[Run],Return[inouts]];
ParallelRun[inouts,monitor,mfunc];
If[OptionValue[DeleteFile],
res=ReadString[Last@#,EndOfFile]&/@inouts;DeleteFile[Flatten[inouts]],
res=Last/@inouts;DeleteFile[First/@inouts];
];
res
]
];


(* ::Subsubsection:: *)
(*PrepareInOut*)


(* ::Text:: *)
(*For the time being we copy options from FermatSession, while later it might be better to do the opposite.*)


Options[PrepareInOut]:=Thread[{In,Out,LibraryLoad}->({In,Out,LibraryLoad}/.Options[FermatSession])];


PrepareInOut[str_String,OptionsPattern[]]:=Module[
{prog,file,in,out},
If[str==="",Print["Fermatica`Private`PrepareInOut: zero string received"];Abort[]];
in=Replace[OptionValue[In],Automatic:>uniquefile["in"]];
file=OpenWrite[in];
out=Replace[OptionValue[Out],Automatic:>uniquefile["out"]];
Close[OpenWrite[out]];(*\[DoubleLongLeftArrow] reserve output file*)
WriteString[file,ReadString[#]]&/@OptionValue[LibraryLoad];
If[StringFreeQ[str,"<<out>>"],
prog=str<>"\n&(S='"<>out<>"');\n&s;",
prog=StringReplace[str,"<<out>>"->out];
];
Monitor[WriteString[file,FermatSession::switches<>"\n"<>prog<>"\n&q;\n&x;"],"Writing program to file...",1];
Close[file];
Return[{in,out}]
]


(* ::Subsubsection::Closed:: *)
(*ParallelRun*)


SetAttributes[ParallelRun,HoldRest];


Module[{dummy},
ParallelRun[inouts:{{_String,_String}..},monitors:(_Symbol|_List):dummy,mfunc:Except[_Rule|_RuleDelayed]:(#2&)]:=Module[
{ins=First/@inouts,n,fcommands,logs,fermats,buffers,new,line,p,error=False,cleanup,delay=2^-20},
fcommands=StringRiffle[(FileNameTake@ToString[$FermatCMD]<>" <"<>FileNameTake@#1<>" >"<>FileNameTake@#2<>"")&@@@inouts,"\n"];
n=Length@ins;
cleanup=(Quiet[Outer[Close@*ProcessConnection,#,{"StandardInput","StandardOutput","StandardError"}]];KillProcess/@#)&;
CStaticMonitor[CheckAbort[
(*start fermat workers*)
Check[fermats=Table[StartProcess[$FermatCMD],{n}],Message[FermatSession::fail,$FermatCMD];cleanup[fermats];(*DeleteFile[Flatten[inouts]];*)
Abort[]];
(*prepare buffers*)
buffers=ConstantArray["",n];
logs=ConstantArray[{},n];
(*load in files fermat workers*)
MapThread[WriteLine[#1,"&(R='"<>#2<>"');"]&,{fermats,ins}];
While[AnyTrue[fermats,ProcessStatus[#]==="Running"&],
Pause[delay];If[delay<1,delay=2*delay];
Do[new=ReadString[fermats[[i]],EndOfBuffer];(*read to the end of the bufer*)
(*Modified 25.05.2020*)
Switch[new,
EndOfFile|EndOfBuffer,Null,
_,
buffers[[i]]=buffers[[i]]<>new;
While[(*Modified 27.01.2022*)True(*/Modified 27.01.2022*),
If[{}===(p=StringPosition[buffers[[i]],"\n",1]),line=EndOfFile,line=StringTake[buffers[[i]],p[[1,1]]-1];buffers[[i]]=StringDrop[buffers[[i]],p[[1,2]]]];
(*Modified 27.01.2022*)If[line===EndOfFile,Break[]];(*/Modified 27.01.2022*)
If[StringMatchQ[line,(StartOfString~~"\\*\\*\\*"~~__)],
logs[[i]]=Append[logs[[i]],Style[line,Red]];
error=True
,
logs[[i]]=Append[logs[[i]],line];
If[StringMatchQ[line,"*>"]&&error,Print["Error while executing "<>(StringSplit[fcommands,"\n"][[i]])];Print[Sequence@@(Style[#,Small]&/@Riffle[logs[[i]],"\n"])];
cleanup[];Abort[]]];
If[Head[Unevaluated[monitors]]===List,
(#=mfunc[Evaluate[#],line,new])&[ReleaseHold[Map[Unevaluated,Hold[monitors],{2}]][[i]]],
monitors[[i]]=mfunc[monitors[[i]],line,new]]
]]
,{i,n}]
],

cleanup[fermats];Abort[]],fcommands,1];
cleanup[fermats];
]
];


(* ::Input:: *)
(*Module[{dummy},*)
(*ParallelRun[inouts:{{_String,_String}..},monitors:(_Symbol|_List):dummy,mfunc:Except[_Rule|_RuleDelayed]:(#2&)]:=Module[*)
(*{ins=First/@inouts,n,fcommands,logs,fermats,buffers,new,line,p,error=False,cleanup,delay=2^-20},*)
(*fcommands=StringRiffle[(FileNameTake@ToString[$FermatCMD]<>" <"<>FileNameTake@#1<>" >"<>FileNameTake@#2<>"")&@@@inouts,"\n"];*)
(*n=Length@ins;*)
(*cleanup=(Quiet[Outer[Close@*ProcessConnection,#,{"StandardInput","StandardOutput","StandardError"}]];KillProcess/@#)&;*)
(*CStaticMonitor[CheckAbort[*)
(*(*start fermat workers*)*)
(*Check[fermats=Table[StartProcess[$FermatCMD],{n}],Message[FermatSession::fail,$FermatCMD];cleanup[fermats];(*DeleteFile[Flatten[inouts]];*)*)
(*Abort[]];*)
(*(*prepare buffers*)*)
(*buffers=ConstantArray["",n];*)
(*logs=ConstantArray[{},n];*)
(*(*load in files fermat workers*)*)
(*MapThread[WriteLine[#1,"&(R='"<>#2<>"');"]&,{fermats,ins}];*)
(*While[AnyTrue[fermats,ProcessStatus[#]==="Running"&],*)
(*Pause[delay];If[delay<1,delay=2*delay];*)
(*Do[new=ReadString[fermats[[i]],EndOfBuffer];(*read to the end of the bufer*)*)
(*(*Modified 25.05.2020*)Switch[new,*)
(*EndOfFile|EndOfBuffer,Null,*)
(*_,buffers[[i]]=buffers[[i]]<>new;*)
(*line="";*)
(*While[line=!=EndOfFile,*)
(*If[{}===(p=StringPosition[buffers[[i]],"\n",1]),line=EndOfFile,line=StringTake[buffers[[i]],p[[1,1]]-1];buffers[[i]]=StringDrop[buffers[[i]],p[[1,2]]]];*)
(*If[line=!=EndOfFile,*)
(*If[StringMatchQ[line,(StartOfString~~"\\*\\*\\*"~~__)],*)
(*logs[[i]]=Append[logs[[i]],Style[line,Red]];*)
(*error=True*)
(*,*)
(*logs[[i]]=Append[logs[[i]],line];*)
(*If[StringMatchQ[line,"*>"]&&error,Print["Error while executing "<>(StringSplit[fcommands,"\n"][[i]])];Print[Sequence@@(Style[#,Small]&/@Riffle[logs[[i]],"\n"])];*)
(*cleanup[];Abort[]]]*)
(*];*)
(*If[Head[Unevaluated[monitors]]===List,*)
(*(#=mfunc[Evaluate[#],Replace[line,EndOfFile->""],new])&[ReleaseHold[Map[Unevaluated,Hold[monitors],{2}]][[i]]],*)
(*monitors[[i]]=mfunc[monitors[[i]],Replace[line,EndOfFile->""],new]]*)
(*]]*)
(*,{i,n}]*)
(*],*)
(**)
(*cleanup[fermats];Abort[]],fcommands,1];*)
(*cleanup[fermats];*)
(*]*)
(*];*)


(* ::Subsubsection::Closed:: *)
(*FermatDetachedSession*)


FermatDetachedSession::fail="Something went wrong when invoking fermat with \"`1`\". Setting variable $FermatCMD to different value might help.";


todo["check that FermatDetachedSession works"];


FermatDetachedSession::switches="&_t;";


Options[FermatDetachedSession]:={Run->True,In->Automatic,Out->Automatic,LibraryLoad->{}};


FermatDetachedSession[str_String,OptionsPattern[]]:=Module[
{file,
in=Replace[OptionValue[In],Automatic:>uniquefile["in"]],
out=Replace[OptionValue[Out],Automatic:>uniquefile["out"]],
fer,log={},line,error=False,
cleanup,res},
cleanup=(Quiet[DeleteFile[in];DeleteFile[out]];
KillProcess[fer,15];
If[ProcessStatus[fer]!="Finished",WriteLine[fer,"&q;"]])&;
file=OpenWrite[in];
WriteString[file,FermatDetachedSession::switches<>"\n\n!!('Input: "<>in<>"');\n\n"<>str<>"
&(S='"<>out<>"');
&s;
!!('Output: "<>out<>"');
&q;
&x;"];
Close[file];
If[!OptionValue[Run],Return[in]];
Check[fer=StartProcess[$FermatCMD],Message[FermatDetachedSession::fail,$FermatCMD]];
WriteLine[fer,"&(R='"<>#<>"');"]&/@OptionValue[LibraryLoad];
WriteLine[fer,"&(R='"<>in<>"');"];
fer
];


GetOutput[fer_]:=Module[{stdout,out},
If[ProcessStatus[fer]=="Running",Return[$Failed]];stdout=ReadString[fer,EndOfBuffer];
out=First@StringCases[stdout,RegularExpression["Output: (.+)"]:>"$1"];
ReadString[out,EndOfFile]
]


GetInput[fer_]:=Module[{stdout,in},
If[ProcessStatus[fer]=="Running",Return[$Failed]];stdout=ReadString[fer,EndOfBuffer];
in=First@StringCases[stdout,RegularExpression["Input: (.+)"]:>"$1"];
ReadString[in,EndOfFile]
]


(* ::Subsubsection::Closed:: *)
(*FermatCoroutine*)


FermatCoroutine::usage="FermatCoroutine[ps] starts Fermat process and assigns the process handle to ps[ProcessObject]. Procedures based on FermatCoroutine are supposed to interact with fermat many times via write-monitor-read cycle. Common data is supposed to be stored as ps[data1] etc.";


Options[FermatCoroutine]={ProcessDirectory->Inherited};


SetAttributes[FermatCoroutine,HoldFirst];


FermatCoroutine::cont="Use `1`[Continue] to continue. Use `1`[KillProcess] to kill process.";


FermatCoroutine[ps_,OptionsPattern[]]:=Module[{fermat,line},
ps[ProcessObject]=fermat=StartProcess[$FermatCMD,ProcessDirectory->OptionValue[ProcessDirectory]];
WriteLine[fermat,"!"];While[ReadLine[fermat]=!=">",Continue[]];ReadString[fermat,EndOfBuffer];
ps[ProcessStatus]:=ProcessStatus[ps[ProcessObject]];
ps[KillProcess]:=KillProcess[ps[ProcessObject]];
ps[Run,commands_List,addtomonitor_:Identity]:=StringRiffle[ps[Run,#,addtomonitor]&/@commands,"\n"];
ps[Run,command_String,addtomonitor_:Identity]:=(
ps[Run]=command;
ps[SeedRandom]=StringReplace[ToString[RandomReal[]],"0."->"ready"];WriteLine[ps[ProcessObject],command<>";!!('"<>ps[SeedRandom]<>"');!"]; ps[Out]="";ps[Continue,addtomonitor]); 
ps[Continue,addtomonitor_:Identity]:=CheckAbort[
While[(line=ReadLine[ps[ProcessObject]])=!=">"<>ps[SeedRandom],line=StringReplace[line,{StartOfLine~~">"->">"<>ToString[Style[ps[Run],Blue],TraditionalForm]<>"\n",s:(StartOfLine~~"***"~~__):>ToString[Style[s,Red],TraditionalForm]}];addtomonitor[line];ps[Out]=ps[Out]<>"\n"<>line];ReadString[ps[ProcessObject],EndOfBuffer];ps[Out],Message[FermatCoroutine::cont,ps];Abort[]];
ps[ReadString,t_:EndOfBuffer]:=ReadString[ps[ProcessObject],t];
ps[Save,fn_String,data_String]:=ps[Run,{"&(S='"<>fn<>"')","!(&o,"<>data<>")","&(S=@)"}];
ps[Exit]:=(While[ps[ProcessStatus]=!="Finished",WriteString[fermat,"&q"]];);True
]


(* ::Text:: *)
(*To do: alleviate CPU load with Mathematica kernel while waiting for Fermat.*)


(* ::Subsection::Closed:: *)
(*Internal functions*)


fermatspecials={"&_n":>"",a1:DigitCharacter~~" "~~a2:DigitCharacter:>a1<>a2};


(* ::Text:: *)
(*Simple tool to choose unique file name*)


uniquefile[s_String]:=Module[{i=1,fn},While[FileExistsQ[fn=$FermatTempDir<>s<>ToString[i]],i++];fn]


(* ::Text:: *)
(*mat2str \[LongDash] matrix to Fermat string.*)
(*imat2str \[LongDash] matrix to Fermat string, only the portion between "[(" and ")]".*)


mat2str::usage="mat2str[smat] coverts Mathematica matrix to Fermat array."
imat2str[m_]:=StringRiffle[Map["    "<>ToString[#,InputForm]&,Transpose[m],{2}],",\n\n",",\n"];
mat2str[m_,mn_String]:=Module[{l=StringRiffle[ToString/@Dimensions[m],","]},"Array "<>mn<>"["<>l<>"];\n["<>mn<>"] := [(\n"<>imat2str[m]<>"\n)];"]


smat2str::usage="smat2str[smat] coverts Mathematica sparse matrix to Fermat sparse array.";
smat2str[smat_,nm_String]:=Module[{r,c},{r,c}=Dimensions[smat];"Array "<>nm<>"["<>ToString[r]<>","<>ToString[c]<>"] Sparse;\n["<>nm<>"] := "<>ismat2str[smat]<>";"];
ismat2str[smat_]:=iarules2str[Most@ArrayRules@smat];
iarules2str[{}]:="[ ]";
iarules2str[arules_]:="[ "<>StringRiffle[StringReplace[ToString[Flatten[#/.Rule->List,1],InputForm]&/@MapAt[Last,GroupBy[SortBy[arules,First],First@*First]/.Association->List,{All,2,All,1}],{"{"->"[ ","}"->"] "}],"\n"]<>"]"


(* ::Text:: *)
(*var2str \[LongDash] variable to Fermat string "&(J=)".*)


var2str=StringRiffle["  &(J="<>ToString[#]<>");"&/@#,"\n"]&;


(* ::Text:: *)
(*str2scl \[LongDash] extract scalar from the stream.*)
(*str2mat \[LongDash] extract matrix from the stream.*)
(**)


str2scl[stream_,sn_String,rule_List:{}]:=Module[{s,e,r,c,start},
s=First@StringPosition[stream,"\n "<>sn<>" := ",1];
e=Last[s]+First@StringPosition[StringDrop[stream,Last[s]],";",1];
ToExpression[StringReplace[StringTake[stream,{Last[s]+1,First[e]-1}],Join[rule,fermatspecials]]]
];


str2lst[stream_,mn_String,rule_List:{}]:=Module[{s,e,r,c,start},
s=First@StringPosition[stream,("\nArray "<>mn<>"[")~~(DigitCharacter..)~~"];\n["<>mn<>"] := ["~~("("|"["),1];
e=Last[s]+First@StringPosition[StringDrop[stream,Last[s]],(")"|"]")~~"];",1];
start=StringTake[stream,s];
r=First@StringCases[start,"["~~r:(DigitCharacter..)~~"]":>ToExpression[r]];
ToExpression["{"<>StringReplace[StringTake[stream,{Last[s]+1,First[e]-1}],Join[rule,fermatspecials]]<>"}"]
];


str2mat[stream_,mn_String,rule_List:{}]:=Module[{s,e,r,c,start},
s=First@StringPosition[stream,("\nArray "<>mn<>"[")~~(DigitCharacter..)~~","~~(DigitCharacter..)~~"];\n["<>mn<>"] := ["~~("("|"["),1];
e=Last[s]+First@StringPosition[StringDrop[stream,Last[s]],(")"|"]")~~"];",1];
start=StringTake[stream,s];
{r,c}=First@StringCases[start,"["~~r:(DigitCharacter..)~~","~~c:(DigitCharacter..)~~"]":>ToExpression["{"<>r<>","<>c<>"}"]];
If[StringTake[start,-1]=="(",Transpose@Partition[#,r],Partition[#,c]]&[ToExpression["{"<>StringReplace[StringTake[stream,{Last[s]+1,First[e]-1}],Join[rule,fermatspecials]]<>"}"]]
];


str2smat[stream_,mn_String,rule_List:{}]:=SparseArray[Flatten[Function[r,{r[[1]],#1}->#2&@@@r[[2;;]]]/@str2sarr[stream,mn,rule]]];


str2sarr[stream_,mn_String,rule_List:{}]:=Module[{s,e,r,c,start},
s=First@StringPosition[stream,("\nArray "<>mn<>"[")~~(DigitCharacter..)~~","~~(DigitCharacter..)~~"] Sparse;\n["<>mn<>"] := [",1];
e=Last[s]+First@StringPosition[StringDrop[stream,Last[s]],"];",1];
start=StringTake[stream,s];
{r,c}=First@StringCases[start,"["~~r:(DigitCharacter..)~~","~~c:(DigitCharacter..)~~"]":>ToExpression["{"<>r<>","<>c<>"}"]];
ToExpression[Fold[StringReplace,StringTake[stream,{Last[s],First[e]}],{{"\n"->""},{"]"~~(" "...)~~"["->"], ["},{"["->"{","]"->"}"},fermatspecials,rule}]]
]


(* ::Text:: *)
(*canmult accepts a list of matrix dimensions and check whether they can be multiplied. I.e., it checks whether the list is of the form {{n1,n2},{n2,n3},...}.*)


canmult=MatchQ[#,{{_,_}..}]&&MatchQ[DeleteDuplicates/@Partition[Take[Flatten[#],{2,-2}],2],{{_}...}]&;


(* ::Section::Closed:: *)
(*End*)


(* ::Text:: *)
(*Print issues*)


If[NameQ["Global`$FermaticaTODO"]&&Symbol["Global`$FermaticaTODO"],
Print["TODO list:"];
Print[Style["\[FilledSmallCircle] "<>#,{"Text",Small}]]&/@todolist];


End[];


EndPackage[]


(* ::Input:: *)
(* *)
