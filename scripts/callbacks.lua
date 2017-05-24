--[[
Copyright 2016, Crank Software Inc.
All Rights Reserved.
For more information email info@cranksoftware.com
** FOR DEMO PURPOSES ONLY **
]]--

require('sbt_infinite_list')

local TouchedList = {}
function RenderText(list, dataIndex, cellIndex)
  local colData = {}
  local col1 = {}
  col1["text"] = wordList[dataIndex]
  
  local clr = TouchedList[dataIndex]
  if(clr == true) then
    col1["clr"] = 0xb94542
  else
    col1["clr"] = 0xf9dbd8
  end
  colData[1] = col1 
  
  return colData
end

local myList

function CBInit(mapargs)
  local file = assert(loadfile(gre.SCRIPT_ROOT .. "/words/wordList.txt"))
  if(file) then
    file()
    myList = InfiniteList:new("Layer.InfiniteList", RenderText, #wordList, 60)
  end
end

function CBQuit(mapargs)
  InfiniteList:Quit()
end

function CBSyncList(mapargs)
--  print("CBSyncList triggered")
  myList:AutoSync()
end

function CBCellTouch(mapargs) 
  local row = mapargs.context_row
  local dataIndex = myList:GetDataIndexFromCell(row)
--  print(string.format("Touched Table Row %d Data Index %d", row, dataIndex))
 
  -- Toggle a flag in the touched field
  if(TouchedList[dataIndex] == true) then
    TouchedList[dataIndex] = nil
  else
    TouchedList[dataIndex] = true
  end
  myList:RefreshCell(row)
end
