#!/usr/bin/env luvit

local Fiber = require('fiber')
local Fs = require('./util')
local Path = require('path')
local Process = require('process')

local d = debug

-- helper to execute `cmd` in shell
local function shell(cmd, callback)
  local child = Process.spawn('/bin/sh', {'-c', cmd}, {})
  child.stdout:on('data', function(data)
    print(data)
  end)
  child.stderr:on('data', function(data)
    print(data)
  end)
  child:on('exit', function (exit_status, term_signal)
    if callback then callback(exit_status ~= 0) end
  end)
end

-- get archive
-- FIXME: implement in luvit
local function wget(url, path, callback)
  shell('wget -qct3 -O - ' .. url .. ' | tar -xzpf - -C ' .. path, callback)
end

--
-- setup module located at `root`
--
function install(root, callback)

  Fiber.new(function(resume, wait)
    local err, result

    -- module manifest exists?
    Fs.stat(Path.join(root, 'config.lua'), resume)
    err = wait()

    -- manifest is present, process it
    if not err then
      local config = require(Path.join(root, 'config'))
      --d(config)

      -- modules has dependencies. fulfil them
      if config.dependencies then

        -- create 'modules' dir
        local path = Path.join(root, 'modules')
        --err = h( Fs.mkdir, path, '0755' )
        Fs.mkdir(path, '0755', resume)
        --Fs.symlink('../modules', 'modules', 'r', resume)
        err = wait()
        -- can't create modules dir? bail out
        if err and err.code ~= 'EEXIST' then
          callback(err)
          return
        end

        -- for each dependency
        local mod_name, url
        for mod_name, url in pairs(config.dependencies) do
          -- try to require mod_name
          if false then
            print('Requiring ' .. mod_name)
            result = pcall(require, mod_name)
          else
            result = false
          end
          if not result then

            print('Installing ' .. mod_name .. ' from ' .. url)

            -- compose module path
            local mod_path = Path.join(path, mod_name)
            local tmp_mod_path = mod_path .. '.tmp'

            -- create temporary download dir
            Fs.mkdir(tmp_mod_path, '0755', resume)
            err = wait()
            -- can't create temporary dir? proceed to next dependency
            if err and err.code ~= 'EEXIST' then
              d(err)
            else

              -- download and unpack tarball to temporary location
              wget(url, tmp_mod_path, resume)
              err = wait()
              if err then
                d(err)
                Fs.rm_fr(tmp_mod_path, resume)
                err = wait()
              else

                -- list archive entries
                Fs.readdir(tmp_mod_path, resume)
                err, result = wait()
                if err then
                  d(err)
                  Fs.rm_fr(tmp_mod_path, resume)
                  err = wait()
                else

                  -- atomically move unpacked archive to proper location.
                  -- if there's the only entry in archive, move it
                  if #result == 1 then
                    local subdir = result[1]
                    -- check if it's directory
                    Fs.stat(Path.join(tmp_mod_path, subdir), resume)
                    err, result = wait()
                    if result and result.is_directory then
                      Fs.rename(Path.join(tmp_mod_path, subdir), mod_path, resume)
                      err = wait()
                      -- remove temporary download dir (it should be empty now)
                      Fs.rmdir(tmp_mod_path, resume)
                    -- the single entry is not directory.
                    -- move the whole archive
                    else
                      Fs.rename(tmp_mod_path, mod_path, resume)
                    end
                  -- if archive contains zero or more than one entries, move the whole archive
                  else
                    Fs.rename(tmp_mod_path, mod_path, resume)
                  end
                  err = wait()
                  if err then
                    d(err)
                    Fs.rm_fr(tmp_mod_path, resume)
                    err = wait()
                  end

                  -- recursively process target module dependencies
                  install(mod_path, resume)
                  err = wait()
                  d('Installed', mod_name, err or 'OK')

                end
              end
            end
          end
        end
      end
    end

    -- build this module
    Fs.stat(Path.join(root, 'Makefile'), resume)
    err = wait()
    if not err then
      print('Found Makefile')
      shell('make -C ' .. root, resume)
      err = wait()
      print('MAKE', err)
    end

    -- setup is done
    if type(callback) then callback() end

  end)

end

--
install(Path.resolve(process.cwd(), ''), function()
  p('DONE')
end)
