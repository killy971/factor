! Copyright (C) 2007 Eduardo Cavazos, Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: namespaces splitting sequences io.files kernel assocs
words vocabs definitions parser continuations inspector debugger
io io.styles io.streams.lines hashtables sorting prettyprint
source-files arrays combinators strings system math.parser
compiler.errors ;
IN: vocabs.loader

SYMBOL: vocab-roots

V{
    "resource:core"
    "resource:extra"
    "resource:work"
} clone vocab-roots set-global

! No such thing as current directory on Windows CE
wince? [ "." vocab-roots get push ] unless

: vocab-dir+ ( vocab str/f -- path )
    >r vocab-name "." split r>
    [ >r dup peek r> append add ] when*
    "/" join ;

: vocab-dir ( vocab -- dir )
    f vocab-dir+ ;

: vocab-source ( vocab -- path )
    ".factor" vocab-dir+ ;

: vocab-docs ( vocab -- path )
    "-docs.factor" vocab-dir+ ;

: vocab-tests ( vocab -- path )
    "-tests.factor" vocab-dir+ ;

: find-vocab-root ( vocab -- path/f )
    vocab-dir vocab-roots get
    swap [ path+ ?resource-path exists? ] curry find nip ;

M: string vocab-root
    dup vocab [ vocab-root ] [ find-vocab-root ] ?if ;

M: vocab-link vocab-root
    dup vocab-link-root [ ] [ vocab-link-name vocab-root ] ?if ;

: vocab-files ( vocab -- seq )
    [
        dup vocab-root dup [
            swap
            2dup vocab-source path+ ,
            2dup vocab-docs path+ ,
            2dup vocab-tests path+ ,
        ] when 2drop
    ] { } make [ ?resource-path exists? ] subset ;

TUPLE: no-vocab name ;

: no-vocab ( name -- * ) \ no-vocab construct-boa throw ;

M: no-vocab summary drop "Vocabulary does not exist" ;

SYMBOL: load-help?

: source-was-loaded t swap set-vocab-source-loaded? ;

: source-wasn't-loaded f swap set-vocab-source-loaded? ;

: load-source ( root name -- )
    [ source-wasn't-loaded ] keep
    [ vocab-source path+ bootstrap-file ] keep
    source-was-loaded ;

: docs-were-loaded t swap set-vocab-docs-loaded? ;

: docs-weren't-loaded f swap set-vocab-docs-loaded? ;

: load-docs ( root name -- )
    load-help? get [
        [ docs-weren't-loaded ] keep
        [ vocab-docs path+ ?run-file ] keep
        docs-were-loaded
    ] [ 2drop ] if ;

: amend-vocab-from-root ( root name -- vocab )
    dup vocab-source-loaded? [ 2dup load-source ] unless
    dup vocab-docs-loaded? [ 2dup load-docs ] unless
    nip vocab ;

: load-vocab-from-root ( root name -- )
    2dup vocab-source path+ ?resource-path exists? [
        2dup create-vocab set-vocab-root
        2dup load-source load-docs
    ] [
        nip no-vocab
    ] if ;

: reload ( name -- )
    [
        dup find-vocab-root dup [
            swap load-vocab-from-root
        ] [
            drop no-vocab
        ] if
    ] with-compiler-errors ;

: require ( vocab -- )
    load-vocab drop ;

: run ( vocab -- )
    dup load-vocab vocab-main [
        execute
    ] [
        "The " write vocab-name write
        " vocabulary does not define an entry point." print
        "To define one, refer to \\ MAIN: help" print
    ] ?if ;

: modified ( seq quot -- seq )
    [ dup ] swap compose { } map>assoc
    [ nip ] assoc-subset
    [ nip source-modified? ] assoc-subset keys ; inline

: vocab-path+ ( vocab path -- newpath )
    swap vocab-root dup [ swap path+ ] [ 2drop f ] if ;

: vocab-source-path ( vocab -- path/f )
    dup vocab-source vocab-path+ ;

: vocab-tests-path ( vocab -- path/f )
    dup vocab-tests vocab-path+ ;

: vocab-docs-path ( vocab -- path/f )
    dup vocab-docs vocab-path+ ;

: modified-sources ( vocabs -- seq )
    [ vocab-source-path ] modified ;

: modified-docs ( vocabs -- seq )
    [ vocab-docs-path ] modified ;

: update-roots ( vocabs -- )
    [ dup find-vocab-root swap vocab set-vocab-root ] each ;

: to-refresh ( prefix -- modified-sources modified-docs )
    child-vocabs
    dup update-roots
    dup modified-sources swap modified-docs ;

: vocab-heading. ( vocab -- )
    nl
    "==== " write
    dup vocab-name swap f >vocab-link write-object ":" print
    nl ;

: load-error. ( triple -- )
    dup first vocab-heading.
    dup second print-error
    drop ;
    ! third "Traceback" swap write-object ;

TUPLE: require-all-error vocabs ;

: require-all-error ( vocabs -- )
    [ vocab-name ] map
    \ require-all-error construct-boa throw ;

M: require-all-error summary
    drop "The require-all operation failed" ;

: require-all ( vocabs -- )
    dup length 1 = [ first require ] [
        [
            [
                [
                    [ require ]
                    [ error-continuation get 3array , ]
                    recover
                ] each
            ] { } make
            dup empty? [ drop ] [
                dup [ load-error. nl ] each
                keys require-all-error
            ] if
        ] with-compiler-errors
    ] if ;

: do-refresh ( modified-sources modified-docs -- )
    2dup
    [ f swap set-vocab-docs-loaded? ] each
    [ f swap set-vocab-source-loaded? ] each
    append prune require-all ;

: refresh ( prefix -- ) to-refresh do-refresh ;

: refresh-all ( -- ) "" refresh ;

GENERIC: (load-vocab) ( name -- vocab )

M: vocab (load-vocab)
    dup vocab-root
    [ swap vocab-name amend-vocab-from-root ] when* ;

M: string (load-vocab)
    [ ".private" ?tail drop reload ] keep vocab ;

M: vocab-link (load-vocab)
    vocab-name (load-vocab) ;

[ [ dup vocab [ ] [ ] ?if (load-vocab) ] with-compiler-errors ]
load-vocab-hook set-global

: vocab-where ( vocab -- loc )
    vocab-source-path dup [ 1 2array ] when ;

M: vocab where vocab-where ;

M: vocab-link where vocab-where ;
