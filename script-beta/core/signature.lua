local files      = require 'files'
local guide      = require 'parser.guide'
local vm         = require 'vm'
local hoverLabel = require 'core.hover.label'
local hoverArg   = require 'core.hover.arg'

local function findNearCall(ast, pos)
    local nearCall
    guide.eachSourceContain(ast.ast, pos, function (src)
        if src.type == 'call'
        or src.type == 'table' then
            if not nearCall or nearCall.start < src.start then
                nearCall = src
            end
        end
    end)
    if not nearCall then
        return nil
    end
    if nearCall.type ~= 'call' then
        return nil
    end
    return nearCall
end

local function makeOneSignature(source, oop, index)
    local label = hoverLabel(source, oop)
    local params = {}
    local i = 0
    for start, finish in label:gmatch '[%(%)%,]%s*().-()%s*%f[%(%)%,]' do
        i = i + 1
        params[i] = {
            label = {start, finish-1},
        }
    end
    return {
        label  = label,
        params = params,
        index  = index,
    }
end

local function makeSignatures(call, pos)
    local node = call.node
    local oop = node.type == 'method'
             or node.type == 'getmethod'
             or node.type == 'setmethod'
    local index
    local args = call.args
    if args then
        for i, arg in ipairs(args) do
            if arg.start <= pos and arg.finish >= pos then
                index = i
                break
            end
        end
        if not index then
            index = #args + 1
        end
    else
        index = 1
    end
    local signs = {}
    vm.eachDef(node, function (src)
        if src.type == 'function' then
            signs[#signs+1] = makeOneSignature(src, oop, index)
        end
    end)
    return signs
end

return function (uri, pos)
    local ast = files.getAst(uri)
    if not ast then
        return nil
    end
    local call = findNearCall(ast, pos)
    if not call then
        return nil
    end
    local signs = makeSignatures(call, pos)
    if not signs or #signs == 0 then
        return nil
    end
    return signs
end
