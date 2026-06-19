-- BspReader Module by JonahSoldier.
AddCSLuaFile()

bspReader = bspReader or {} --Likely to use this in other addons, don't want to store redundant data.

-- // Data {{{
	--Used for reading bit values
	bspReader.int8 = {0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80}
	bspReader.int16 = {0x0001, 0x0002, 0x0004, 0x0008, 0x0010, 0x0020, 0x0040, 0x0080, 0x0100, 0x0200, 0x0400, 0x0800, 0x1000, 0x2000, 0x4000, 0x8000 }
-- // }}}

--[[ NOTE:
	All of the data tables here are 1-indexed, because that's how lua tables work.
	Leaves are 0-indexed, however. So unless you're using one of the get functions you
	need to make sure you offset them.

	This doesn't apply to things like clusterLeafConnections, as these are for getting specific entries solely
	and so just take the actual leaf exactly as it is.
--]]

-- // Data Read-Ins {{{

	-- // Helpers {{{
		function bspReader.getOffset(mapFile, lumpInd)
			mapFile:Seek(8 + 16 * lumpInd)
			return mapFile:ReadULong(), mapFile:ReadULong() --offs, len
		end

		function bspReader.splitBitField(bitField, splitCount)
			local int1, int2 = 0, 0
			for i=1, splitCount, 1 do 
				int1 = int1 + bit.band(bspReader.int16[i], bitField)
			end

			for i=1, 16 - splitCount, 1 do -- todo: I haven't checked this is right, because I don't need it rn.
				if not(bit.band(bitField, bspReader.int16[splitCount + i]) == 0) then 
					int2 = int2 + bspReader.int16[i]
				end
			end
			return int1, int2
		end
	-- // }}}

	function bspReader.readLeafData()
		--If multiple addons use this we don't want to do redundant work.
		if bspReader.leafDataRead then return end
		
		local mapFile = file.Open("maps/" .. game.GetMap() .. ".bsp", "rb" , "GAME")
		bspReader.leafMins = {}
		bspReader.leafMaxs = {}
		bspReader.leafClusterConnections = {}
		bspReader.clusterLeafConnections = {}
		bspReader.leafArea = {}
		--bspReader.leafFlags = {} --Idk if we need these


		mapFile:Seek(4)
		version = mapFile:ReadLong() --Format is different in older maps.

		--The leaf lump
		local offset, length = bspReader.getOffset(mapFile, 10)

		local bytesPer = ((version > 19) and 32) or 56
		for i = 1, length / bytesPer, 1 do
			mapFile:Seek((offset + 4) + ((i-1) * bytesPer))
			local cluster = mapFile:ReadShort()
			if not (cluster == -1) then
				bspReader.leafClusterConnections[i-1] = cluster
				local connections = bspReader.clusterLeafConnections[cluster]
				if istable(connections) then
					table.insert(connections, i-1)
				else
					bspReader.clusterLeafConnections[cluster] = {i-1}
				end
			end

			--Area & Flags BitField
			local field_areaFlags = mapFile:ReadUShort()
			local area, flags = bspReader.splitBitField(field_areaFlags, 9)
			bspReader.leafArea[i] = area

			--mapFile:Seek((offset + 8) + ((i-1) * bytesPer)) --mins and maxes
			--BBOX mins & maxes
			local mins = Vector(mapFile:ReadShort(), mapFile:ReadShort(), mapFile:ReadShort())
			local maxs = Vector(mapFile:ReadShort(), mapFile:ReadShort(), mapFile:ReadShort())
			bspReader.leafMins[i] = mins
			bspReader.leafMaxs[i] = maxs
		end


		mapFile:Close()
		print("[BSPReader] Read Leaf Data")
		bspReader.leafDataRead = true
	end

	function bspReader.readNodeData()
		if bspReader.nodeDataRead then return end

		local mapFile = file.Open("maps/" .. game.GetMap() .. ".bsp", "rb" , "GAME")
		bspReader.nodePlaneIndexes = {}
		bspReader.nodeChildren1 = {}
		bspReader.nodeChildren2 = {}

		--the node lump
		local nodeOffset, nodeLength = bspReader.getOffset(mapFile, 5)

		for i = 1, nodeLength / 32, 1 do
			mapFile:Seek(nodeOffset + ((i-1) * 32))

			bspReader.nodePlaneIndexes[i] = mapFile:ReadLong()

			mapFile:Seek(nodeOffset + 4 + ((i-1) * 32))
			bspReader.nodeChildren1[i] = mapFile:ReadLong()
			mapFile:Seek(nodeOffset + 8 + ((i-1) * 32))
			bspReader.nodeChildren2[i] = mapFile:ReadLong()
		end	


		mapFile:Close()
		print("[BSPReader] Read Node Data")
		bspReader.nodeDataRead = true
	end

	function bspReader.readPlaneData()
		if bspReader.planeDataRead then return end

		local mapFile = file.Open("maps/" .. game.GetMap() .. ".bsp", "rb" , "GAME")
		bspReader.planeNormals = {}
		bspReader.planeDistances = {}

		--the plane lump
		local planeOffset, planeLength = bspReader.getOffset(mapFile, 1)

		for i = 1, planeLength / 20, 1 do
			mapFile:Seek(planeOffset + ((i-1) * 20))

			bspReader.planeNormals[i] = Vector(mapFile:ReadFloat(), mapFile:ReadFloat(), mapFile:ReadFloat())
			bspReader.planeDistances[i] = mapFile:ReadFloat()
		end
		
		mapFile:Close()
		print("[BSPReader] Read Plane Data")
		bspReader.planeDataRead = true
	end

	function bspReader.readPVSData()
		if bspReader.pvsDataRead then return end

		local mapFile = file.Open("maps/" .. game.GetMap() .. ".bsp", "rb" , "GAME")
		bspReader.pvsIndices = {}
		bspReader.pasIndices = {}
		bspReader.visBitData = {}
		bspReader.clusterCount = -1 --This line isn't needed, but makes it easier to find all the data defined here.

		--find the vis lump
		local visIndex, _ = bspReader.getOffset(mapFile, 4)
		mapFile:Seek(visIndex)

		local numClusters = mapFile:ReadLong()--cluster count
		bspReader.clusterCount = numClusters

		for i = 1, numClusters, 1 do --Read all of the offsets 
			local pvs, pas = mapFile:ReadLong(), mapFile:ReadLong()
			if not pvs or not pas then --todo: Somewhere down the line I probably want to support these maps.
				ErrorNoHaltWithStack("[BSPReader] Issue reading map data, might be an unsupported format.")
				return 
			end 

			table.insert(bspReader.pvsIndices, pvs)
			table.insert(bspReader.pasIndices, pas)
		end

		--[[todo: We don't get the length of this properly here at all, and so read in a lot more than necessary. 
			That data isn't easily available (We might need to work it out manually which kinda sucks) so this is here as a placeholder.

			Future vers might require getting bspReader.pvsIndices[#bspReader.pvsIndices] (or pas) and then literally reading through it
			until we run out of clusters in-order to figure out the exact length.
		--]]
		local byteCount = math.ceil(numClusters/8)
		for i=1, byteCount * numClusters, 1 do --Byte count per cluster * number of clusters. -- WRONG. RLE means these are variable length
			local byte = mapFile:ReadByte()
			if not byte then break end -- todo: Remove after above todo's fix

			table.insert( bspReader.visBitData, byte)
		end

		mapFile:Close()
		print("[BSPReader] Read PVS Data")
		bspReader.pvsDataRead = true
	end

	function bspReader.readBrushData(brush_contents) --Probably more memory intensive due to subtables, so only read what we need.
		if bspReader.brushDataRead and bspReader.brushDataRead[brush_contents] then return end

		local mapFile = file.Open("maps/" .. game.GetMap() .. ".bsp", "rb" , "GAME")
		bspReader.brushes = {}
		bspReader.brushContents = {}

		local brushOffs, brushLen = bspReader.getOffset(mapFile, 18)
		local brushSideOffs, brushSideLen = bspReader.getOffset(mapFile, 19)

		for i = 1, brushLen/12, 1 do 
			mapFile:Seek(brushOffs + ((i-1) * 12))
			local firstSide = mapFile:ReadLong()
			local numSides = mapFile:ReadLong()
			local contents = mapFile:ReadLong()

			if bit.band(contents, brush_contents) == 0 then continue end

			local br = {}
			bspReader.brushes[i] = br
			bspReader.brushContents[i] = contents

			for j=1, numSides, 1 do
				local brushSide = {}
				table.insert(br, brushSide)

				mapFile:Seek(brushSideOffs + (firstSide * 8) + ((j-1) * 8))
				brushSide.planeNum = mapFile:ReadUShort()
			end
		end

		mapFile:Close()
		print("[BSPReader] Read Brush Data")
		bspReader.brushDataRead = bspReader.brushDataRead or {}
		bspReader.brushDataRead[brush_contents] = true
	end

	--[[ --idk if we actually need this. I don't read any cluster data (directly) in advSound.
	function bspReader.readClusterData() 
		if bspReader.clusterDataRead then return end

		local mapFile = file.Open("maps/" .. game.GetMap() .. ".bsp", "rb" , "GAME")


		mapFile:Close()
		print("[BSPReader] Read Cluster Data")
		bspReader.clusterDataRead = true
	end--]]

-- // }}}

-- // Utilities {{{
	function bspReader.getPVS( clusterIndex )
		assert(bspReader.pvsDataRead, "[BSPReader] : Tried to use GetPVS without having read PVSData")

		if not clusterIndex or clusterIndex == -1 then return {} end
		local pvsOffset = bspReader.pvsIndices[clusterIndex+1]
		local numClusters = bspReader.clusterCount

		local hitClusters = 0
		local PVS = {}

		 --PVSOffset is bits from start of chunk, so we need to convert to our table index.
		local offs = ((bspReader.clusterCount * 2 * 4) + 4)
		local iter = 0

		while hitClusters < numClusters do --RLE decoding
			local byte = bspReader.visBitData[(pvsOffset - offs) + iter + 1]
			iter = iter + 1
			if byte == 0 then 
				local skip = bspReader.visBitData[(pvsOffset - offs) + iter + 1]
				iter = iter + 1
				hitClusters = hitClusters + (skip * 8)
			else
				for i = 1, 8, 1 do
					--insert every 1 bit's index to PVS
					if bit.band(byte, bspReader.int8[i]) > 0 then
						table.insert(PVS, hitClusters -1 + i)
					end
				end
				hitClusters = hitClusters + 8
			end
		end
		return PVS
	end

	function bspReader.getPVSAtPoint( point ) --Reduce repeated code
		local leaf = bspReader.getVisLeaf( point )
		local cluster =  bspReader.getVisLeafCluster( leaf )
	
		return bspReader.getPVS( cluster )
	end

	 --todo: Check if we can make this a local function. I've had issues with those seemingly being garbage-collected on client before,
	 --I've made this part of the bspReader table for now because I prefer being able to rely on it to work correctly. But no one should
	 --ever really be calling this function directly.
	function bspReader._getVisLeafRecurse(px, py, pz, nodeIndex)
		if nodeIndex < 0 then
			return -(nodeIndex + 1) --unwind
		end

		local planeIndex = bspReader.nodePlaneIndexes[nodeIndex + 1]

		local normal = bspReader.planeNormals[planeIndex + 1]
		local dist = bspReader.planeDistances[planeIndex + 1]

		local nx, ny, nz = normal:Unpack()
		if (nx * px) + (ny * py) + (nz * pz) - dist > 0 then
			local child = bspReader.nodeChildren1[nodeIndex + 1]
			return bspReader._getVisLeafRecurse(px, py, pz, child)
		else
			local child = bspReader.nodeChildren2[nodeIndex + 1]
			return bspReader._getVisLeafRecurse(px, py, pz, child)
		end
	end

	function bspReader.getVisLeaf( point ) --we're basically just using BSP for what it's meant for here.
		local x, y, z = point:Unpack()
		return bspReader._getVisLeafRecurse(x, y, z, 0)
	end

	-- // Get Functions {{{
		function bspReader.getClusterVisleaves( clusterIndex )
			return bspReader.clusterLeafConnections[clusterIndex]
		end
		
		function bspReader.getVisLeafCluster( index )
			return bspReader.leafClusterConnections[index]
		end

		function bspReader.getVisLeafBounds( index ) --Don't modify the vectors returned by this or you'll fuck up the array.
			return bspReader.leafMins[index + 1], bspReader.leafMaxs[index + 1]
		end

		function bspReader.getVisLeafArea( index )
			return bspReader.leafArea[index + 1]
		end
	-- // }}}
	
-- // }}}
