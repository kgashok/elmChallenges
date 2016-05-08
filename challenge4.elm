import Html exposing (..)
import Html.App as HA
import Html.Attributes as Attr exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Json exposing ((:=))
import String
import Task exposing (..)
import Set
import String exposing (join )
import Time exposing (second, Time)
import AnimationFrame exposing (times)

-- MODEL

type alias User = 
  { name : String
  , avatar_url : String
  , repos_url : String
  , languages : List String
  }

type alias Model = 
  { query : String
  , lastKeyPress : Maybe Time
  , user : Maybe User
  , lastUserName : String
  }

init : Model 
init = { query = "evancz", lastKeyPress = Nothing, user = Nothing, lastUserName = ""}

-- UPDATE 

type Msg = 
  Update (Maybe User) | UpdateQuery String | Tick Time | DoNothing

lookupUser : String -> Cmd Msg
lookupUser query =
  ((Http.get decodeUser ("http://api.github.com/users/" ++ query))
  `andThen` \user ->
    (Http.get decodeLanguages user.repos_url `onError` 
      (\msg -> succeed [toString msg]))
  `andThen` \languages -> 
      let 
        user' : User
        user' =  { user | languages = notEmptyUnique languages }
      in succeed user') 
  |> Task.toMaybe 
  |> Task.perform (\_ -> DoNothing) Update
  

notEmptyUnique : List String -> List String
notEmptyUnique xs = 
  List.filter (\x -> not <| String.isEmpty x) <| Set.toList <| Set.fromList xs

decodeLanguages : Json.Decoder (List (String))
decodeLanguages = (Json.list  <| Json.oneOf 
  [ (Json.at ["language"] Json.string)
  , (Json.succeed "")
  ])

decodeUser : Json.Decoder (User)
decodeUser = Json.object4 User
    ("name" := Json.string) 
    ("avatar_url" := Json.string)
    ("repos_url" := Json.string)
    (Json.succeed [])

update : Msg -> Model -> (Model, Cmd Msg)
update msg model = 
  case msg of
    UpdateQuery str -> 
      ({ model | query = str, lastKeyPress = Nothing }, Cmd.none)
    
    Tick time -> 
      case model.lastKeyPress of
        Nothing -> ({model| lastKeyPress = Just time}, Cmd.none)
        Just t ->  
          if ((time - t) > second) && (model.query /= model.lastUserName)
          then ({model| lastKeyPress = Just t, lastUserName = model.query }, lookupUser model.query)
          else (model, Cmd.none)

    Update user -> 
      ({ model | user = user}, Cmd.none)

    DoNothing -> (model, Cmd.none)

-- VIEW

view : Model -> Html Msg
view model =
  let 
    field =
      input
        [ placeholder "Please enter the GitHub username"
        , value model.query
        , onInput UpdateQuery
        , myStyle
        ]
        []

    messages =
      case model.user of
        Nothing ->
          let
            msg = case model.lastKeyPress of 
              Nothing -> "Looking for user..."
              Just t -> "User not found :("
          in
            [ div [ myStyle ] [ text msg ] ]

        Just user ->
            [ div [ myStyle ] [ text user.name ]
            , img  [ src user.avatar_url, imgStyle] []
            , div [ myStyle ] [ text <| knownLanguages user.languages]
            ]
  in
    div [] ((div [ myStyle ] [ text "GitHub Username" ]) :: field :: messages)


knownLanguages : List String -> String 
knownLanguages langs = 
  "Knows the following programming languages: " ++ (join ", " langs)

imgStyle : Attribute msg
imgStyle =
  style
    [ ("display", "block")
    , ("margin-left", "auto")
    , ("margin-right", "auto")
    ]


myStyle : Attribute msg
myStyle =
  style
    [ ("width", "100%")
    , ("height", "40px")
    , ("padding", "10px 0")
    , ("font-size", "2em")
    , ("text-align", "center")
    ]


-- WIRING


main : Program Never
main =
  HA.program
    { init = (init, lookupUser "evancz")
    , update = update
    , view = view
    , subscriptions = 
        (\_ -> times Tick) 
    }
