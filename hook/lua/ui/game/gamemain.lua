do
local originalCreateUI = CreateUI

function CreateUI(isReplay)
    originalCreateUI(isReplay)
	import("/mods/Random Improvements/displayrings.lua").Init()
end

end
