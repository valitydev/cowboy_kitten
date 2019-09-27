# cowboy_kitten
Respond with style

## Description
This application provides `cowboy` `stream_handler` to send customized response bodies
depending on status code. For every response that cowboy is about to send, `cowboy_kitten` will
check status code against rules, you set and modify response body if nessesary.

## Usage

Just add cowboy_kitten to the stream chain. It is recomended to add it just before the `cowboy_stream_h` handler. `resp_bodies` should be provided inside the `env` map, that is a part of cowboy setup.  
#### Response body format
Response bodies can be one of two types: files or binary strings, if you want to send file, use `{file, Filename}` tuple, binary strings can be used directly.

### Example
 ```
cowboy:start_clear(http, [{port, 8080}], #{
    stream_handlers => [cowboy_kitten, cowboy_stream_h],
    env => #{
        dispatch => Dispatch,
        resp_bodies => #{
            500 => {file, "500_error_resp_file"},
            400 => <<"400_error_msg">>
        }
    }
}).
 ```
