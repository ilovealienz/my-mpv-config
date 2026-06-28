if package.config:sub(1,1) == "\\" then
    mp.command("apply-profile windows")
else
    mp.command("apply-profile linux")
end