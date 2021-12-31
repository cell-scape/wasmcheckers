(module
    ;; Memory Allocation
    (memory $mem 1)
    ;; Global Variables and Constants
    (global $currentTurn (mut i32) (i32.const 0))
    (global $BLACK i32 (i32.const 1))
    (global $WHITE i32 (i32.const 2))
    (global $CROWN i32 (i32.const 4))
    ;; Row offset: (x, y) = x + 8y;
    (func $indexForPosition (param $x i32) (param $y i32) (result i32)
        (i32.add
            (i32.mul
                (i32.const 8)
                (get_local $y)
            )
            (get_local $x)
        )
    )
    ;; Byte Offset: (x, y) = (x + 8y) * 4
    (func $offsetForPosition (param $x i32) (param $y i32) (result i32)
        (i32.mul
            (call $indexForPosition (get_local $x) (get_local $y))
            (i32.const 4)
        )
    )
    ;; Check if a piece is crowned
    (func $isCrowned (param $piece i32) (result i32)
        (i32.eq
            (i32.and (get_local $piece) (get_global $CROWN))
            (get_global $CROWN)
        )
    )
    ;; Check if a piece is white
    (func $isWhite (param $piece i32) (result i32)
        (i32.eq
            (i32.and (get_local $piece) (get_global $WHITE))
            (get_global $WHITE)
        )
    )
    ;; Check if a piece is black
    (func $isBlack (param $piece i32) (result i32)
        (i32.eq
            (i32.and (get_local $piece) (get_global $BLACK))
            (get_global $BLACK)
        )    
    )
    ;; Add a crown to a piece
    (func $withCrown (param $piece i32) (result i32)
        (i32.or (get_local $piece) (get_global $CROWN))
    )
    ;; Remove a crown from a piece
    (func $withoutCrown (param $piece i32) (result i32)
        (i32.and (get_local $piece) (i32.const 3))
    )
    ;; Set a piece on the board
    (func $setPiece (param $x i32) (param $y i32) (param $piece i32)
        (i32.store
            (call $offsetForPosition
                (get_local $x)
                (get_local $y)
            )
            (get_local $piece)
        )
    )
    ;; Get a piece from the board. Out of range causes a trap
    (func $getPiece (param $x i32) (param $y i32) (result i32)
        (if (result i32)
            (block (result i32)
                (i32.and
                    (call $inRange
                        (i32.const 0)
                        (i32.const 7)
                        (get_local $x)
                    )
                    (call $inRange
                        (i32.const 0)
                        (i32.const 7)
                        (get_local $y)
                    )
                )
            )
            (then
                (i32.load
                    (call $offsetForPosition
                        (get_local $x)
                        (get_local $y)
                    )
                )
            )
            (else
                (unreachable)
            )
        )
    )
    ;; Detect if values are within inclusive range
    (func $inRange (param $low i32) (param $high i32) (param $value i32) (result i32)
        (i32.and
            (i32.ge_s (get_local $value) (get_local $low))
            (i32.le_s (get_local $value) (get_local $high))
        )
    )
    ;; Get the current turn owner (white or black)
    (func $getTurnOwner (result i32)
        (get_global $currentTurn)
    )
    ;; At the end of a turn, switch turn owner to other player
    (func $toggleTurnOwner
        (if (i32.eq (call $getTurnOwner) (i32.const 1))
            (then (call $setTurnOwner (i32.const 2)))
            (else (call $setTurnOwner (i32.const 1)))
        )
    )
    ;; Set turn owner
    (func $setTurnOwner (param $piece i32)
        (set_global $currentTurn (get_local $piece))
    )
    ;; Determine if it's a player's turn
    (func $isPlayersTurn (param $player i32) (result i32)
        (i32.gt_s
            (i32.and (get_local $player) (call $getTurnOwner))
            (i32.const 0)
        )
    )
    ;; Should a piece get crowned? Black at row 0, White at row 7
    (func $shouldCrown (param $pieceY i32) (param $piece i32) (result i32)
        (i32.or
            (i32.and
                (i32.eq
                    (get_local $pieceY)
                    (i32.const 0)
                )
                (call $isBlack (get_local $piece))
            )
            (i32.and
                (i32.eq
                    (get_local $pieceY)
                    (i32.const 7)
                )
                (call $isWhite (get_local $piece))
            )
        )
    )
    ;; Converts a piece into a crown and invokes host notifier
    (func $crownPiece (param $x i32) (param $y i32)
        (local $piece i32)
        (set_local $piece (call $getPiece (get_local $x) (get_local $y)))
        (call $setPiece (get_local $x) (get_local $y)
            (call $withCrown (get_local $piece)))
        (call $notify_piececrowned (get_local $x) (get_local $y))
    )
    ;; Get Distance
    (func $distance (param $x i32) (param $y i32) (result i32)
        (i32.sub (get_local $x) (get_local $y))
    )
    ;; Determine if a move is valid
    (func $isValidMove (param $fromX i32) (param $fromY i32) (param $toX i32) (param $toY i32) (result i32)
        (local $player i32)
        (local $target i32)
        (set_local $player (call $getPiece (get_local $fromX) (get_local $fromY)))
        (set_local $target (call $getPiece (get_local $toX) (get_local $toY)))
        (if (result i32)
            (block (result i32)
                (i32.and
                    (call $validJumpDistance (get_local $fromY) (get_local $toY))
                    (i32.and
                        (call $isPlayersTurn (get_local $player))
                        (i32.eq (get_local $target) (i32.const 0))
                    )
                )
            )
            (then
                (i32.const 1)
            )
            (else
                (i32.const 0)
            )
        ) 
    )

    ;; Function Exports
    (export "indexForPosition" (func $indexForPosition))
    (export "offsetForPosition" (func $offsetForPosition))
    (export "isCrowned" (func $isCrowned))
    (export "isWhite" (func $isWhite))
    (export "isBlack" (func $isBlack))
    (export "withCrown" (func $withCrown))
    (export "withoutCrown" (func $withoutCrown))
    (export "setPiece" (func $setPiece))
    (export "getPiece" (func $getPiece))
    (export "inRange" (func $inRange))
)