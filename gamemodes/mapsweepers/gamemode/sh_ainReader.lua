-- AinReader Module by JonahSoldier.
AddCSLuaFile()

ainReader = ainReader or {} --Likely to use this in other addons, don't want to store redundant data.

--i lov the ai node .s..


-- // Data Read-Ins {{{
	function ainReader.readNodeData()
		if ainReader.nodeDataRead then return end 

		local fileName = "maps/graphs/" .. game.GetMap() .. ".ain"
		if not file.Exists(fileName, "GAME") then return false end

		local ainFile = file.Open(fileName, "rb", "GAME")
		ainFile:Seek(8)
		local numNodes = ainFile:ReadLong()

		ainReader.nodePositions = {}
		ainReader.nodeTypes = {}
		ainReader.nodeZones = {}

		local perNode = (16 + (4*10) + 1 + 4)
		for i=1, numNodes, 1 do 
			ainFile:Seek(12 + perNode  * (i-1)) --Assumes ""NumHulls"" of 10, I'm not sure where this number comes from so I'm concerned about it.
			table.insert( ainReader.nodePositions, Vector(ainFile:ReadFloat(), ainFile:ReadFloat(), ainFile:ReadFloat()) )
			
			ainFile:Skip(4 + (4*10))
			table.insert(ainReader.nodeTypes, ainFile:ReadByte()) --type (

			ainFile:Skip(2)
			table.insert(ainReader.nodeZones, ainFile:ReadShort())
		end

		ainReader.nodeDataRead = true
		return true
	end

	function ainReader.readLinkData() --TODO: Bad data read-in
		if ainReader.linkDataRead then return end 

		local fileName = "maps/graphs/" .. game.GetMap() .. ".ain"
		if not file.Exists(fileName, "GAME") then return false end

		local ainFile = file.Open(fileName, "rb", "GAME")
		
		ainFile:Seek(8)
		local numNodes = ainFile:ReadLong()

		local perNode = (16 + (4*10) + 1 + 4)
		local offs = 12 + (numNodes*perNode)
		ainFile:Seek( offs )
		local numLinks = ainFile:ReadLong()

		ainReader.nodeConnections = {}
		ainReader.nodeConnectionMoves = {} --bitflag for each HULL type indicating what capabilities they need to move between
		for i=1, numNodes, 1 do
			table.insert(ainReader.nodeConnections, {})
			table.insert(ainReader.nodeConnectionMoves, {})
		end

		local perLink = (2 + 2 + (1*10))
		for i=1, numLinks, 1 do
			ainFile:Seek(offs + 4 + (i-1) * perLink)
			local srcId = ainFile:ReadShort()
			local destId = ainFile:ReadShort()
			local moves = {}
			for i=1, 10 do
				table.insert(moves, ainFile:ReadByte())
			end

			table.insert(ainReader.nodeConnections[srcId+1], destId+1)
			table.insert(ainReader.nodeConnectionMoves[srcId+1], moves)
		
			table.insert(ainReader.nodeConnections[destId+1], srcId+1)  
			table.insert(ainReader.nodeConnectionMoves[destId+1], moves)
		end

		ainReader.linkDataRead = true
		return true
	end
-- // }}}