opt server_output = "tests/output/server.luau"
opt client_output = "tests/output/client.luau"

funct Test = {
    call: Async,
    args: (Foo: u8, Bar: string),
    rets: enum { Success, Fail }
}
