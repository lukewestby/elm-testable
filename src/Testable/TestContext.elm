module Testable.TestContext (Component, TestContext, startForTest, update, currentModel, assertCurrentModel, assertHttpRequest, resolveHttpRequest, advanceTime) where

{-| A `TestContext` allows you to manage the lifecycle of an Elm component that
uses `Testable.Effects`.  Using `TestContext`, you can write tests that exercise
the entire lifecycle of your component.

@docs Component, TestContext, startForTest, update

# Inspecting
@docs currentModel, assertCurrentModel, assertHttpRequest

# Simulating Effects
@docs resolveHttpRequest, advanceTime
-}

import ElmTest as Test exposing (Assertion)
import Testable.Effects as Effects exposing (Effects)
import Testable.EffectsLog as EffectsLog exposing (EffectsLog)
import Testable.Http as Http
import Time exposing (Time)


{-| A component that can be used to create a `TestContext`
-}
type alias Component action model =
  { init : ( model, Effects action )
  , update : action -> model -> ( model, Effects action )
  }


{-| The representation of the current state of a testable component, including
a representaiton of any pending Effects.
-}
type alias TestContext action model =
  { state : model
  , component : Component action model
  , effects : EffectsLog action
  , errors : List String
  }


{-| Create a `TestContext` for the given Component
-}
startForTest : Component action model -> TestContext action model
startForTest component =
  let
    ( initialState, initialEffects ) =
      component.init
  in
    { component = component
    , state = initialState
    , effects =
        EffectsLog.empty
    , errors = []
    }
      |> applyEffects initialEffects


{-| Apply an action to the component in a given TestContext
-}
update : action -> TestContext action model -> TestContext action model
update action context =
  let
    ( newModel, newEffects ) =
      context.component.update action context.state
  in
    { context
      | state = newModel
    }
      |> applyEffects newEffects


applyEffects : Effects action -> TestContext action model -> TestContext action model
applyEffects newEffects context =
  case EffectsLog.insert newEffects context.effects of
    ( newEffectsLog, immediateActions ) ->
      List.foldl update { context | effects = newEffectsLog } immediateActions


{-| Assert that a given Http.Request has been made by the componet under test
-}
assertHttpRequest : Http.Request -> TestContext action model -> Assertion
assertHttpRequest request testContext =
  case EffectsLog.httpAction request (Http.ok "") testContext.effects of
    Just _ ->
      Test.pass

    Nothing ->
      Test.fail
        ("Expected an HTTP request to have been made:"
          ++ "\n    Expected: "
          ++ toString request
          ++ "\n    Actual: "
          ++ toString testContext.effects
        )


{-| Simulate an HTTP response
-}
resolveHttpRequest : Http.Request -> Result Http.RawError Http.Response -> TestContext action model -> TestContext action model
resolveHttpRequest request response context =
  case
    EffectsLog.httpAction request response context.effects
      |> Result.fromMaybe ("No pending HTTP request: " ++ toString request)
  of
    Ok ( newLog, actions ) ->
      List.foldl
        update
        { context | effects = newLog }
        actions

    Err message ->
      { context | errors = (message :: context.errors) }


{-| Simulate the passing of time
-}
advanceTime : Time -> TestContext action model -> TestContext action model
advanceTime milliseconds context =
  case
    EffectsLog.sleepAction milliseconds context.effects
  of
    ( newLog, actions ) ->
      List.foldl
        update
        { context | effects = newLog }
        actions


{-| Get the current state of the component under test
-}
currentModel : TestContext action model -> Result (List String) model
currentModel context =
  case context.errors of
    [] ->
      Ok context.state

    errors ->
      Err errors


{-| A convenient way to assert about the current state of the component under test
-}
assertCurrentModel : model -> TestContext action model -> Assertion
assertCurrentModel expectedModel context =
  context
    |> currentModel
    |> Test.assertEqual (Ok expectedModel)
