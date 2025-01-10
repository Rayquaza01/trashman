--- Parses arguments to find flag arguments and file arguments
--- Flag arguments start with --
--- Any arguments after the literal argument "--" will *always* be interpreted as a file, regardless of whether it starts with --
--- Returns array of flag arguments and array of file arguments
--- @param argv string[]
--- @return string[], string[]
function parse_arguments(argv)
    local file_arguments = {}
    local flag_arguments = {}

    local is_always_file = false

    for arg in all(argv) do
        if not is_always_file then
            if arg == "--" then
                is_always_file = true
            elseif arg:find("^%-%-") then
                add(flag_arguments, arg)
            else
                add(file_arguments, arg)
            end
        else
            add(file_arguments, arg)
        end
    end

    return flag_arguments, file_arguments
end
