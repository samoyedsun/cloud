local emiter = class("emiter")

function emiter:ctor()
    self.process = {}
end

function emiter:on(name, func)
    table.insert(self.process, {name = name, process = func})
end

function emiter:emit(name, ... )
    for _,v in pairs(self.process) do 
        if string.match(v.name, name) then
            v.process(...)
        end
    end
end

return emiter