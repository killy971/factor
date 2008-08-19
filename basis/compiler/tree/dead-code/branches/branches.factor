! Copyright (C) 2008 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: sequences namespaces kernel accessors assocs sets fry
arrays combinators columns stack-checker.backend compiler.tree
compiler.tree.combinators compiler.tree.dead-code.liveness
compiler.tree.dead-code.simple ;
IN: compiler.tree.dead-code.branches

M: #if mark-live-values* look-at-inputs ;

M: #dispatch mark-live-values* look-at-inputs ;

: look-at-phi ( value outputs inputs -- )
    [ index ] dip swap dup [ <column> look-at-values ] [ 2drop ] if ;

M: #phi compute-live-values*
    #! If any of the outputs of a #phi are live, then the
    #! corresponding inputs are live too.
    [ out-d>> ] [ phi-in-d>> ] bi look-at-phi ;

SYMBOL: if-node

M: #branch remove-dead-code*
    [ [ [ (remove-dead-code) ] map ] change-children ]
    [ if-node set ]
    bi ;

: remove-phi-inputs ( #phi -- )
    dup [ out-d>> ] [ phi-in-d>> flip ] bi
    filter-corresponding
    flip >>phi-in-d
    drop ;

: live-value-indices ( values -- indices )
    [ length ] keep live-values get
    '[ , nth , key? ] filter ; inline

: drop-values ( values indices -- node )
    [ drop filter-live ] [ nths ] 2bi
    [ make-values ] keep
    [ drop ] [ zip ] 2bi
    #shuffle ;

: insert-drops ( nodes values indices -- nodes' )
    '[ , drop-values suffix ] 2map ;

: hoist-drops ( #phi -- )
    if-node get swap
    [ phi-in-d>> ] [ out-d>> live-value-indices ] bi
    '[ , , insert-drops ] change-children drop ;

: remove-phi-outputs ( #phi -- )
    [ filter-live ] change-out-d
    drop ;

M: #phi remove-dead-code*
    {
        [ hoist-drops ]
        [ remove-phi-inputs ]
        [ remove-phi-outputs ]
        [ ]
    } cleave ;
