local net = require("@lune/net")

local copy = require("./utils/copy")
local types = require("./utils/result_option_conv")
local Option = types.Option
local Result = types.Result
type Option<T> = types.Option<T>
type Result<T, E> = types.Result<T, E>

local Github = {}
export type Github = typeof(setmetatable(Github :: GithubFields, { __index = Github }))
type GithubFields = {
	req: net.FetchParams,
	retries: number,
}

export type Config = {
	authToken: Option<string>,
	retries: Option<number>,
}
export type GithubOperation = "FetchReleases" | "GetMetadata" | "GetActionArtifacts"

local API_BASE_URL = "https://api.github.com"
local DEFAULT_MAX_RETRIES = 5
local DEFAULT_CONFIG: Config = {
	authToken = Option.None :: Option<string>,
	retries = Option.Some(DEFAULT_MAX_RETRIES) :: Option<number>,
}

function Github.new(repo: string, config: Option<Config>)
	local configOrDefault = config:unwrapOr(DEFAULT_CONFIG)
	return setmetatable(
		{
			req = {
				url = API_BASE_URL .. "/repos/" .. repo,
				headers = {
					["Authorization"] = configOrDefault.authToken:mapOr("", function(token)
						return `Bearer {token}`
					end),
				},
			} :: net.FetchParams,
			config = config,
			retries = configOrDefault.retries:unwrapOr(DEFAULT_MAX_RETRIES),
		} :: GithubFields,
		{
			__index = Github,
		}
	)
end

-- FIXME: Remove unknown usage here
function Github.queueTransactions(self: Github, operations: { GithubOperation }): { Result<unknown, string> }
	local queue: { (retries: number) -> Result<unknown, string> } = table.create(#operations)

	for _, operation: GithubOperation in operations do
		local req: net.FetchParams = copy(self.req)

		if operation == "FetchReleases" then
			req.url ..= "/releases"
			req.method = "GET"
		end

		--  TODO: Other methods

		table.insert(queue, function(retries: number)
			local lastCode: number
			for _ = 1, retries do
				local resp = net.request(req)
				lastCode = resp.statusCode

				if not resp.ok then
					continue
				end

				return Result.Ok(net.jsonDecode(resp.body))
			end

			return Result.Err(`Github::RespErr(statusCode={lastCode})`)
		end)
	end

	local results = {}
	for _, req in queue do
		local ok, respRes: Result<unknown, string> = pcall(req, self.retries)
		table.insert(results, if ok then respRes else Result.Err("Github::IoError"))
	end

	return results
end

return Github
