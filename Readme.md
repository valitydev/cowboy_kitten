# kitten_cowboy
Respond with style

## Description
This application provides `cowboy` `stream_handler` to send customized response bodies
depending on status code. For every response that cowboy is about to send, `kitten_cowboy` will
check status code against rules, you set and modify response body if nessesary.
