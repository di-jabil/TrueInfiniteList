--[[
Copyright 2016, Crank Software Inc.
All Rights Reserved.
For more information email info@cranksoftware.com
** FOR DEMO PURPOSES ONLY **
]]--

--- This is inspired by the JS version:
-- https://github.com/roeierez/infinite-list
--
-- In place of a DOM element, we pass the callbacks two integers:
-- * Item index: This is the index of the entry we are looking at directly
-- * Table index: This is the table index we are showing at
-- numItems = Number of items of virtual data
-- numCells = Number of cells in the table (numCells <= numItems)
-- numVisible = Number of table cells visible in the table (numVisible <= numCells)
--
-- firstItem = Index of the first item (Table Cell 1)
-- lastItem = Index of the last item (Table Cell numCells)
--
--visibleUICells < settableUICells < virtualDataCells < realDataCells

InfiniteList = {}

function InfiniteList:new(tableName, renderCB, numItems, numRows, numCols)
  local newList = {}
  setmetatable(newList, self)
  self.__index = self
  
  if(numCols == nil) then
  	numCols = 1
  end
  
  -- this is some changes for Git
  
  
  local numCells = numRows * numCols
--  self:dbg("new infinite table, numItems: %d numCells:%d", numItems, numCells)
  
  newList.tableName = tableName
  newList.renderCB = renderCB
  
  local tInfo = gre.get_table_attrs(newList.tableName, "width", "height", "yoffset")
  newList.tableHeight = tInfo.height
  newList.tableWidth = tInfo.width  
  newList.numCols = numCols
  newList.numRows = numRows
  
  
  local cInfo = gre.get_table_cell_attrs(newList.tableName, 1, 1, "width", "height")
  newList.cellHeight = cInfo.height
  newList.cellWidth = cInfo.width

  --newList.numVisible = (newList.tableHeight + newList.cellHeight) / newList.cellHeight
  newList.numVisibleYCells = math.ceil(newList.tableHeight / newList.cellHeight)
  if(newList.numRows < newList.numVisibleYCells) then
    newList.numVisibleYCells = newList.numRows
  end
  
  newList.numVisibleXCells = math.ceil(newList.tableWidth / newList.cellWidth)
  if(newList.numCols < newList.numVisibleXCells) then
    newList.numVisibleXCells = newList.numCols
  end
  
  newList.numVisible = newList.numVisibleYCells * newList.numVisibleXCells
  if(numItems == nil) then
    numItems = 10000
  end
  newList.numItems = numItems
  
--  if(numCells == nil) then
--    numCells = newList.numVisibleYCells * 4
--  end
  
  if(numCells > numItems) then -- corner case: more cells than items TBD
    numRows = math.ceil(numItems / numCols) -- trunk rows 
  end
  
  numCells = numRows * numCols
  
  newList.numCells = numCells -- 60
  newList.numRows = numRows -- 60
 
  -- Initialize the list with content at the top
  newList.firstItem = 1   
  newList.lastItem = newList.numCells --1 + newList.numCells
  
  -- Seed the list with the current content
  newList:SyncCellsToData()
  
  -- Resize the table control
  gre.set_table_attrs(newList.tableName, { rows = newList.numRows })
  
  
  -- config the initial yoffset -- 
  
  local row_initialPos =  math.floor((newList.numRows-newList.numVisibleYCells)/2) -- initiial row offset 
  local pix_initialPos = row_initialPos * newList.cellHeight  
  
  local newYOffset = tInfo.yoffset - pix_initialPos -- 0- pix_initialPos = -750
  newList.initialOffset = newYOffset -- initial offset
  gre.set_table_attrs(newList.tableName, { ["yoffset"] = newList.initialOffset }) -- shift by the initial offset, 
  
  
  -- define the top threshold 
  local row_topThre =  10 -- initiial row offset 
  local yPix_topThre = -row_topThre * newList.cellHeight -- -300
  
  -- define the bottom threshold
  
  local row_bottomThre = 15
  local pix_bottomThre = -(newList.numRows - row_bottomThre) * newList.cellHeight -- -1350  
  
  -- config the thresholds
  newList.yPix_topThre = yPix_topThre
  newList.row_topThre = row_topThre
  
  newList.yPix_bottomThre = pix_bottomThre
  newList.row_bottomThre = row_bottomThre
  
  print(string.format("Initialization Done. It starts at the %dth row. The top threshold is the %dth row; the bottom threshold is the %dth row",row_initialPos, row_topThre, newList.numRows - row_bottomThre))
  
  return newList
end

function InfiniteList:dbg(fmt, ...)
  local msg = string.format(fmt, unpack(arg))
  print(msg)
end

-- Convert a 1 based table cell index to a 1 based data index
function InfiniteList:GetDataIndexFromCell(ci)
  return self.firstItem + (ci - 1)  
end

-- Convert a 1 based data index to a 1 based table cell index
function InfiniteList:GetCellIndexFromData(di)
  return di - (self.firstItem - 1)
end

function InfiniteList:RefreshCell(cellIndex)
  self:SyncCellsToData(cellIndex, cellIndex)
end

--Synchronize a set of table cells to the backing store data
function InfiniteList:SyncCellsToData(cellStartIndex, cellEndIndex)
  if(cellStartIndex == nil) then
    cellStartIndex = 1
    cellEndIndex = self.numCells
  end
  
  local di = self:GetDataIndexFromCell(cellStartIndex) -- the starting data index
  
  local row = cellStartIndex - 1
  local data = {}
  for ci=cellStartIndex,cellEndIndex,self.numCols do -- only decide the number of iterations
    local columnData = self:ItemRenderer(di, ci) -- ci not used
    row = row + 1
    --TODO Support a short hand for a single column of data
    for c=1,#columnData do
      local entry = columnData[c]
      for k,v in pairs(entry) do
        local nk = string.format("%s.%s.%d.%d", self.tableName, k, row, c)
 --       self:dbg("Setting %s, %s", nk, v)
        data[nk] = v
      end
    end
    di = (di + self.numCols) % self.numItems -- the increment of data index
    if (di == 0) then
      di = self.numItems
    end
    --TODO: Measure some sort of insertion index here that makes sense ..
  end
  
  gre.set_data(data)
end

-- Return a table with a set of local table variables for each column 
function InfiniteList:ItemRenderer(dataIndex, cellIndex)
--    self:dbg("itemRenderer, %d dataIndex %d cellIndex", dataIndex, cellIndex)
    return self:renderCB(dataIndex, cellIndex)
end

function CalculateReset(pix_currentPos, list) -- calcualte the new cell range
  print(string.format("calcualting the resetting, current pix: %.2f, initial offset: %.2f", pix_currentPos, list.initialOffset))
  local newFirstItem
  local newLastItem
  
  local pDiff = math.abs(list.initialOffset - pix_currentPos)
  local rDiff = math.floor(pDiff/list.cellHeight)
  
  -- decide top or bottom
  if math.abs(pix_currentPos) <= math.abs(list.initialOffset) then -- top extension
    if list.firstItem < rDiff then -- cross the 0 line
      newFirstItem = (list.firstItem - rDiff) % list.numItems 
    elseif list.firstItem > rDiff then
      newFirstItem = (list.firstItem - rDiff + 1) % list.numItems
    else
      newFirstItem = list.numItems
    end  
    if list.lastItem < rDiff then -- cross the 0 line
      newLastItem = (list.lastItem - rDiff) % list.numItems 
    elseif list.lastItem > rDiff then
      newLastItem = (list.lastItem - rDiff + 1) % list.numItems
    else
      newLastItem = list.numItems
    end
  else -- bottom extension
    if list.firstItem + rDiff ~= 10000 then 
      newFirstItem = (list.firstItem + rDiff) % list.numItems 
    else
      newFirstItem = list.numItems
    end
    if list.lastItem + rDiff ~= 10000 then 
      newLastItem = (list.lastItem + rDiff) % list.numItems 
    else
      newLastItem = list.numItems
    end
  end
  
  
  print(string.format("the new first item is %d, the new last item is %d", newFirstItem, newLastItem))
  
  return newFirstItem, newLastItem
end

function InfiniteList:RefreshDataAndResetPos(currentPos)

  local newFirstItem
  local newLastItem

  newFirstItem, newLastItem = CalculateReset(currentPos, self) -- calcualte the new cell range
  -- set the new cell range
  self.firstItem = newFirstItem
  self.lastItem = newLastItem
    
  -- refresh the data
  self:SyncCellsToData() 
    
  -- reset pos
  gre.set_table_attrs(self.tableName, { ["yoffset"] = self.initialOffset })
  
  print("reset done")

end

function InfiniteList:AutoSync()
  local tInfo = gre.get_table_attrs(self.tableName, "yoffset")
  if(tInfo.yoffset >= 0) then  
    print("reached the upper limit")
    return
  end
   
  
  local offscreenCount = (math.floor((-1 * tInfo.yoffset) / self.cellHeight)) * self.numCols; -- # of invisible cells beyond the top of the viewable window
--  self:dbg("offscreen rows %d; current offset: %.2f; top theshold: %.2f; bottom theshold: %.2f", offscreenCount, tInfo.yoffset, self.yPix_topThre, self.yPix_bottomThre)

  if(tInfo.yoffset >= self.yPix_topThre) then --reached the top threshold
    print("reached the top threshold")
    
    self:RefreshDataAndResetPos(tInfo.yoffset) -- refresh the data and reset the pos
   
    return
  elseif (tInfo.yoffset <= self.yPix_bottomThre) then --reached the top threshold
    print("reached the bottom threshold")
    
    self:RefreshDataAndResetPos(tInfo.yoffset) -- refresh the data and reset the pos

    return
  end
end
--[[
  local thresholdCount = math.ceil(self.numRows * .20) * self.numCols -- 20% of the overall cells, 12
  local topThreshold = thresholdCount -- from top
  local bottomThreshold = self.numCells - self.numVisible - thresholdCount -- left to be shown 39
  

  local newFirstItem = self.firstItem
  if(offscreenCount <= topThreshold) then
    newFirstItem = self.firstItem - thresholdCount
    if(newFirstItem < 1) then
      newFirstItem = 1
    end
    print(string.format("trigger 1, newFirstItem: %d",newFirstItem))
  elseif(offscreenCount > bottomThreshold) then -- >39, reached the bottom area
    newFirstItem = self.firstItem + thresholdCount -- this is the shift !!!
    if(newFirstItem + self.numCells - 1 > self.numItems) then
      newFirstItem = self.numItems - self.numCells + 1
    end
    print(string.format("trigger2, newFirstItem: %d",newFirstItem))
   else
    print(string.format("in the middle area, the current trigger is %d", bottomThreshold))
  end
  self:dbg("Content Check %d offscreen %d top %d bottom, first item: %d; last item: %d", offscreenCount, topThreshold, bottomThreshold, 
              newFirstItem, self.lastItem)
  
  
  
   -- below is the shift process, triggered by newFirstItem, mainly to calculate the new offset, and set new first item and last item
  
  
  if(newFirstItem == self.firstItem) then
    return
  end
  
  self:dbg("Change top virtual index from %d to %d, %d", self.firstItem, newFirstItem, thresholdCount)
  -- ie Old = 1, New = 13 -> Add to the yoffset value by cellHeight * difference 
  local rowDiff =  math.floor(newFirstItem/self.numCols) - math.floor(self.firstItem/self.numCols)   -- 13 - 1 = 12 
  local yPixDiff = rowDiff * self.cellHeight  -- 12 * height 
  
  self.firstItem = newFirstItem
  self.lastItem = self.numCells + self.firstItem
  
  self:SyncCellsToData()
  
  local newYOffset = tInfo.yoffset + yPixDiff
  gre.set_table_attrs(self.tableName, { ["yoffset"] = newYOffset }) -- shift offset, 
 --]]
