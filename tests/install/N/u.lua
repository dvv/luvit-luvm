#!/usr/bin/env luvit

local Fiber = require('fiber')
local Fs = require('fs')
local Path = require('path')
local gmatch = require('string').gmatch

local function mkdirp(path, perm, continue)
  path = Path.normalize(path)
  --[[while path ~= '' do
    local i, j = path:find('[^/]*$')
    local dir = path:sub(1, i - 1)
    path = path:sub(i + 1)
    p(dir)
  end]]--
  Fiber.new(function(resume, wait)
    local pa = ''
    local err
    for dir in path:gmatch('[^/]+') do
      pa = Path.join(pa, dir)
      p(dir, pa)
      Fs.mkdir(pa, perm, resume)
      err = wait()
      if err and err.code ~= 'EEXIST' then
        continue(err)
        break
      end
    end
    continue()
  end)
end

mkdirp('/foo/bar/bar', '0755', function(err)
  p('DONE', err)
end)
