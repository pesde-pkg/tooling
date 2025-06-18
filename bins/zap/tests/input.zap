opt server_output = "output/server.luau"
opt client_output = "output/client.luau"

funct Test = {
    call: Async,
    args: (Foo: u8, Bar: string),
    rets: enum { Success, Fail }
}
