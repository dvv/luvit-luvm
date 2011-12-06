#!/usr/bin/env luvit

local Fiber = require('fiber')
local Fs = require('fs')
local Path = require('path')
local Process = require('process')

-- helper to execute `cmd` in shell
local function shell(cmd, continue)
  local child = Process.spawn('/bin/sh', {'-c', cmd}, {})
  child.stdout:on('data', function(data)
    print(data)
  end)
  child.stderr:on('data', function(data)
    print(data)
  end)
  child:on('exit', function (exit_status, term_signal)
    if (continue) then continue(exit_status ~= 0) end
  end)
end

-- get archive helper
-- FIXME: implement in luvit
local function wget(url, path, continue)
  --shell('wget -qct3 -O - ' .. url .. ' | tar -xzpf - -C ' .. path, continue)
  p('CP', url, path)
  shell('cp -a /home/dvv/LUA/MOD/repo/' .. url .. ' ' .. path, continue)
end

-- TODO: perform cleanup
local function fail(err)
  error(err)
end

--
-- setup module located at `root`
--
function install(root, continue)

  Fiber.new(function (resume, wait)
    local err, result
    --[[local Table = require('table')
    local function h(f, ...)
      local args = {...}
      Table.insert(args, #args+1, resume)
      local err, result
      f(unpack(args))
      return wait()
    end]]--

    -- module manifest exists?
    Fs.stat(Path.join(root, 'config.lua'), resume)
    err, result = wait()

    -- manifest is present, process it
    if not err then
      local config = require(Path.join(root, 'config'))
      --p(config)

      -- modules has dependencies. fulfil them
      if config.dependencies then

        -- create 'modules' dir
        local path = Path.join(root, 'modules')
        --err, result = h( Fs.mkdir, path, '0755' )
        Fs.mkdir(path, '0755', resume)
        err, result = wait()
        if err and err.code ~= 'EEXIST' then fail(err) end

        -- for each dependency
        local mod_name, url
        for mod_name, url in pairs(config.dependencies) do
          -- try to require mod_name
          result = pcall(require, mod_name)
          if not result then

            print('Installing ' .. mod_name .. ' from ' .. url)

            -- compose module path
            local mod_path = Path.join(path, mod_name)
            local tmp_mod_path = mod_path .. '.tmp'

            -- create temporary download dir
            Fs.mkdir(tmp_mod_path, '0755', resume)
            err, result = wait()
            if err and err.code ~= 'EEXIST' then fail(err) end

            -- download and unpack tarball to temporary location
            wget(url, tmp_mod_path, resume)
            err, result = wait()
            if err then
              --rm_fr(tmp_mod_path)
              fail(err)
            end

            -- list archive entries
            Fs.readdir(tmp_mod_path, resume)
            err, result = wait()
            if err then
              --rm_fr(tmp_mod_path)
              fail(err)
            end

            -- atomically move unpacked archive to proper location.
            -- if there's the only entry in archive, move it
            if #result == 1 then
              Fs.rename(Path.join(tmp_mod_path, result[1]), mod_path, resume)
              err, result = wait()
              -- remove temporary download dir
              Fs.rmdir(tmp_mod_path, resume)
            -- if archive contains zero or more than one entries, move the whole archive
            else
              Fs.rename(tmp_mod_path, mod_path, resume)
            end
            err, result = wait()
            if err then
              --rm_fr(tmp_mod_path)
              fail(err)
            end

            -- recursively process target module dependencies
            install(mod_path, resume)
            err, result = wait()
            p('Installed', err or 'OK')

          end

        end
      end

    end

    -- build this module
    Fs.stat(Path.join(root, 'Makefile'), resume)
    err, result = wait()
    if not err then
      print('Found Makefile')
      shell('make -C ' .. root, resume)
      err, result = wait()
      print('MAKE', err)
    end

    -- setup is done
    if continue then continue() end

  end)

end

--
install('/home/dvv/LUA/MOD/N', function()
  p('DONE')
end)
