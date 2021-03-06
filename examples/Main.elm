module Main exposing (..)

import Html.App
import RandomGif exposing (init, update, view)
import Testable


main : Program Never
main =
    Html.App.program
        { init = Testable.init <| init "dc6zaTOxFJmzC" "funny cats"
        , update = Testable.update update
        , view = view
        , subscriptions = always Sub.none
        }
