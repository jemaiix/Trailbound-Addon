-- Read-only market observations and conservative, per-craft estimates.
ForeverAssistEconomy={Version='1.8.54'}
local E=ForeverAssistEconomy
local account,settings,options
local panels,hooks={},{}
local function safe(v)return not issecretvalue or not issecretvalue(v)end
local function call(fn,...)if type(fn)~='function'then return end;local ok,a,b,c,d=pcall(fn,...);if ok then return a,b,c,d end end
local function itemID(link)return type(link)=='string'and tonumber(link:match('item:(%d+)'))end
local function num(v)return safe(v)and type(v)=='number'and v>=0 and v or nil end
local function marketKey()return (GetRealmName and GetRealmName()or 'Realm')..'|'..(UnitFactionGroup and UnitFactionGroup('player')or '')end
local function money(v)if v==nil then return '|cffaaaaaaUnknown|r'end;return (v<0 and '|cffff7777-'or '|cff77eeaa+')..ForeverAssistMoney(math.abs(v))..'|r'end
function E.Observe(id,price,source)
 if not account or not num(id)or not num(price)or price<=0 then return end
 local prices=account.auctionMemory[marketKey()]or {};account.auctionMemory[marketKey()]=prices
 prices[id]={price=price,seen=time(),source=source or 'AH observed'}
end
function E.Price(id)
 if not account or not id then return end
 local source=settings().craftPriceSource or 'Auto'
 if source=='Auto'or source=='Auctionator'then
  local api=Auctionator and Auctionator.API and Auctionator.API.v1
  local price=api and call(api.GetAuctionPriceByItemID,'ForeverAssist',id)
  if num(price)and price>0 then
   local days=call(api.GetAuctionAgeByItemID,'ForeverAssist',id)
   if not num(days)or days<=(settings().craftPriceMaxDays or 14)then return price,'Auctionator',num(days)and math.floor(days*86400)or nil end
  end
 end
 if source=='Auto'or source=='TSM'then
  local price=TSM_API and call(TSM_API.GetCustomPriceValue,'dbmarket','i:'..id)
  if num(price)and price>0 then return price,'TSM market',nil end
 end
 if source=='Auto'or source=='Memory'then
  local saved=account.auctionMemory[marketKey()]and account.auctionMemory[marketKey()][id]
  if saved and time()-saved.seen<=(settings().craftPriceMaxDays or 14)*86400 then return saved.price,saved.source,time()-saved.seen end
 end
end
function E.Item(id)
 local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
 if not fn or not id then return {}end
 local values={pcall(fn,id)};if not values[1]then return {}end
 local name,link,sell=values[2],values[3],values[12]
 if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id)end
 return {name=safe(name)and name or nil,link=safe(link)and link or nil,vendor=num(sell),bindType=num(values[15]),stack=num(values[9])}
end
function E.Recipe(id)
 if not account or not id then return end
 if E.sessionRecipes and E.sessionRecipes[id]then return E.sessionRecipes[id]end
 local ui=C_TradeSkillUI
 local schematic=ui and call(ui.GetRecipeSchematic,id,false)
 if type(schematic)=='table'and not (issecrettable and issecrettable(schematic))then
  local output=call(ui.GetRecipeOutputItemData,id,{})
  local result=schematic.outputItemID or type(output)=='table'and (output.itemID or itemID(output.hyperlink))
  if not num(result)then return end
  local recipe={id=id,name=schematic.name,itemID=result,quantity=schematic.quantityMin or 1,reagents={},incomplete=false,seen=time()}
  recipe.variable=schematic.quantityMax and schematic.quantityMax~=recipe.quantity
  for _,slot in ipairs(schematic.reagentSlotSchematics or {})do
   if slot.required or slot.reagentType==(Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 0)then
    local reagent=slot.reagents and slot.reagents[1]
    if reagent and reagent.itemID and #slot.reagents==1 and num(slot.quantityRequired)then recipe.reagents[#recipe.reagents+1]={itemID=reagent.itemID,quantity=slot.quantityRequired}
    else recipe.incomplete=true end -- Never pick an arbitrary quality/currency/optional allocation.
   end
  end
  account.craftingRecipes[id]=recipe;E.sessionRecipes=E.sessionRecipes or {};E.sessionRecipes[id]=recipe;return recipe
 end
 return account.craftingRecipes[id]
end
function E.LegacyRecipe(index,craft)
 if not num(index)or index<1 then return end
 local output=call(craft and GetCraftItemLink or GetTradeSkillItemLink,index);local id=itemID(output);if not id then return end
 local name=call(craft and GetCraftInfo or GetTradeSkillInfo,index)
 local count=call(craft and GetCraftNumReagents or GetTradeSkillNumReagents,index)
 if not num(count)then return end
 local min=call(craft and GetCraftNumMade or GetTradeSkillNumMade,index)
 local r={id=(craft and 'craft:'or 'trade:')..id,itemID=id,name=name,quantity=num(min)and math.max(1,min)or 1,reagents={}}
 for i=1,count do
  local link=call(craft and GetCraftReagentItemLink or GetTradeSkillReagentItemLink,index,i)
  local _,_,quantity=call(craft and GetCraftReagentInfo or GetTradeSkillReagentInfo,index,i)
  if itemID(link)and num(quantity)then r.reagents[#r.reagents+1]={itemID=itemID(link),quantity=quantity}else r.incomplete=true end
 end
 account.craftingRecipes[r.id]=r;return r
end
function E.Estimate(recipe)
 if not recipe then return end
 local result={recipe=recipe,cost=0,missing={},sources={}}
 if recipe.incomplete then result.missing[#result.missing+1]='Recipe has unsupported or unselected reagent choices'end
 for _,reagent in ipairs(recipe.reagents)do
  local price,source=E.Price(reagent.itemID)
  local merchant=account.merchantPrices[reagent.itemID]
  if merchant and (not price or merchant<price)then price,source=merchant,'Vendor observed'end
  local info=E.Item(reagent.itemID)
  if not price then result.missing[#result.missing+1]=info.name or ('Item '..reagent.itemID)
  else result.cost=result.cost+price*reagent.quantity;result.sources[source]=true end
 end
 if #result.missing>0 then result.cost=nil end
 local item=E.Item(recipe.itemID);result.vendor=item.vendor and item.vendor*recipe.quantity
 local price,source,age=E.Price(recipe.itemID);result.source,result.age=source,age
 -- Bind-on-pickup/quest items cannot be auctioned. Do not show an AH profit.
 if item.bindType==1 or item.bindType==4 then price=nil;result.notAuctionable=true end
 result.sale=price and price*recipe.quantity
 local deposit
 local ah=C_AuctionHouse;local commodity=ah and call(ah.GetItemCommodityStatus,recipe.itemID)
 if ah and Enum and Enum.ItemCommodityStatus and commodity==Enum.ItemCommodityStatus.Commodity then deposit=call(ah.CalculateCommodityDeposit,recipe.itemID,settings().craftAuctionDuration or 1,recipe.quantity)end
 result.deposit=num(deposit)
 if result.deposit==nil and result.vendor and result.vendor>0 then
  local duration=settings().craftAuctionDuration or 1
  result.deposit=math.floor(result.vendor*(settings().craftDepositPercent or 15)/100*({1,2,4})[duration]);result.depositEstimated=true
 end
 result.tax=result.sale and math.floor(result.sale*(settings().craftAuctionCut or 5)/100)
 if result.cost and result.vendor then result.vendorProfit=result.vendor-result.cost end
 if result.cost and result.sale and result.deposit then
  result.profit=result.sale-result.tax-result.deposit-result.cost
  result.successProfit=result.sale-result.tax-result.cost
 end
 return result
end
function E.TrainerRecipe(index)
 if not num(index)or index<1 then return end
 local link=call(GetTrainerServiceItemLink,index);local spell=type(link)=='string'and tonumber(link:match('spell:(%d+)'))
 local recipe=spell and E.Recipe(spell);if recipe then return recipe end
 local name=call(GetTrainerServiceInfo,index);if not name then return end
 for _,profession in pairs(ForeverAssistProfessionData or {})do
  for _,entry in ipairs(profession.records or {})do
   if entry.kind=='recipe'and entry.name==name then
    local found=E.Recipe(entry.spellID)
    if found then if recipe and recipe.id~=found.id then return end;recipe=found end
   end
  end
 end
 if recipe then return recipe end
 for _,saved in pairs(account.craftingRecipes)do if saved.name==name then if recipe then return end;recipe=saved end end
 return recipe
end
function E.CurrentRecipe(host)
 if host==ClassTrainerFrame then
  local index=GetTrainerSelectionIndex and GetTrainerSelectionIndex()
  if not index or index<1 then return end
  return E.TrainerRecipe(index),index
 end
 local form=host and host.CraftingPage and host.CraftingPage.SchematicForm
 local info=form and form.GetRecipeInfo and call(form.GetRecipeInfo,form)
 if info and info.recipeID then
  local recipe=E.Recipe(info.recipeID)
  local transaction=form.GetTransaction and call(form.GetTransaction,form)
  local choices=transaction and transaction.CreateOptionalCraftingReagentInfoTbl and call(transaction.CreateOptionalCraftingReagentInfoTbl,transaction)
  if recipe and type(choices)=='table'and #choices>0 then
   recipe=ForeverAssistExtras.Copy(recipe)
   for _,reagent in ipairs(choices)do if num(reagent.itemID)and num(reagent.quantity)then recipe.reagents[#recipe.reagents+1]={itemID=reagent.itemID,quantity=reagent.quantity}else recipe.incomplete=true end end
   local output=call(C_TradeSkillUI.GetRecipeOutputItemData,info.recipeID,choices)
   if output and num(output.itemID)then recipe.itemID=output.itemID end
  end
  return recipe
 end
 if host==CraftFrame then return E.LegacyRecipe(GetCraftSelectionIndex and GetCraftSelectionIndex(),true)end
 return E.LegacyRecipe(GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex(),false)
end
function E.SearchMats(recipe,crafts)
 recipe=recipe or E.searchRecipe;if not recipe then return end
 crafts=num(crafts)and math.max(1,math.floor(crafts))or 1
 local terms,seen={},{}
 for _,reagent in ipairs(recipe.reagents)do
  local name=E.Item(reagent.itemID).name
  if not name then print('|cffd2b077Trailbound:|r Material names are loading. Try Search mats again.');return end
  local quantity=num(reagent.quantity)
  if not quantity or quantity<1 then print('|cffd2b077Trailbound:|r Material quantities are unavailable for this recipe.');return end
  if seen[name]then seen[name].quantity=seen[name].quantity+quantity*crafts
  else local term={searchString=name,isExact=true,quantity=quantity*crafts};terms[#terms+1]=term;seen[name]=term end
 end
 if #terms==0 then return end
 E.pendingSearch=terms;E.SearchPending()
end
function E.SearchPending()
 if not E.pendingSearch then return end
 local host=AuctionHouseFrame or AuctionFrame
 if not host or not host:IsShown()then print('|cffd2b077Trailbound:|r Materials queued. Open the auction house to search them.');return end
 local api=Auctionator and Auctionator.API and Auctionator.API.v1
 if api and api.MultiSearchAdvanced then
  local ok=pcall(api.MultiSearchAdvanced,'Trailbound',E.pendingSearch);if ok then E.pendingSearch=nil;return end
 end
 if api and api.MultiSearchExact then
  local names,quantities={},{}
  for _,term in ipairs(E.pendingSearch)do names[#names+1]=term.searchString;quantities[#quantities+1]=term.searchString..' x'..term.quantity end
  local ok=pcall(api.MultiSearchExact,'Trailbound',names);if ok then print('|cffd2b077Trailbound:|r Required: '..table.concat(quantities,', '));E.pendingSearch=nil;return end
 end
 -- Own sequential exact-item browse queue, advanced only by result events.
 E.nativeSearch={terms=E.pendingSearch,index=1};E.pendingSearch=nil;E.SearchNext()
end
function E.SearchNext()
 local q=E.nativeSearch;if not q then return end
 local entry=q.terms[q.index];if not entry then E.nativeSearch=nil;print('|cffd2b077Trailbound:|r Material search complete; prices saved.');return end
 local term=entry.searchString;q.requiredQuantity=entry.quantity
 if C_AuctionHouse and C_AuctionHouse.SendBrowseQuery then
  if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady()then return end
  local sorts=Enum and Enum.AuctionHouseSortOrder and {{sortOrder=Enum.AuctionHouseSortOrder.Price,reverseSort=false}}or {}
   local ok=pcall(C_AuctionHouse.SendBrowseQuery,{searchString=term,sorts=sorts,filters={},itemClassFilters={}});if ok then print('|cffd2b077Trailbound:|r Searching '..term..' — need '..entry.quantity);q.waiting=true;q.started=GetTime();return end
 elseif QueryAuctionItems then local ok=pcall(QueryAuctionItems,term,nil,nil,0,false,nil,false,true);if ok then print('|cffd2b077Trailbound:|r Searching '..term..' — need '..entry.quantity);q.waiting=true;q.started=GetTime();return end end
 print('|cffd2b077Trailbound:|r This client cannot start material searches. Install Auctionator for multi-item searches.');E.nativeSearch=nil
end
function E.CaptureMarket(event,id)
 local ah=C_AuctionHouse
 if event=='COMMODITY_SEARCH_RESULTS_UPDATED'and ah then
  local price
  for i=1,(call(ah.GetNumCommoditySearchResults,id)or 0)do local info=call(ah.GetCommoditySearchResultInfo,id,i);if info and num(info.unitPrice)and (not price or info.unitPrice<price)then price=info.unitPrice end end
  if price then E.Observe(id,price)end
 elseif event=='ITEM_SEARCH_RESULTS_UPDATED'and ah then
  local price
  for i=1,(call(ah.GetNumItemSearchResults,id)or 0)do local info=call(ah.GetItemSearchResultInfo,id,i);local amount=info and num(info.buyoutAmount);local qty=info and num(info.quantity);if amount and amount>0 and qty and qty>0 then local p=amount/qty;if not price or p<price then price=p end end end
  if price and id.itemID then E.Observe(id.itemID,price)end
 elseif event=='AUCTION_HOUSE_BROWSE_RESULTS_UPDATED'or event=='AUCTION_HOUSE_BROWSE_RESULTS_ADDED'then
  for _,r in ipairs(ah and call(ah.GetBrowseResults)or {})do
   if r.itemKey and num(r.minPrice)and r.minPrice>0 then
    local id=r.itemKey.itemID;local commodity=call(ah.GetItemCommodityStatus,id)
    if Enum and Enum.ItemCommodityStatus and commodity==Enum.ItemCommodityStatus.Commodity or E.Item(id).stack==1 then E.Observe(id,r.minPrice)end
   end
  end
 elseif event=='AUCTION_ITEM_LIST_UPDATE'and GetNumAuctionItems then
  local prices={}
  for i=1,(GetNumAuctionItems('list')or 0)do
   local item=itemID(call(GetAuctionItemLink,'list',i));local values={pcall(GetAuctionItemInfo,'list',i)}
   local qty,buyout=values[4],values[11]
   if item and num(qty)and qty>0 and num(buyout)and buyout>0 then local p=buyout/qty;if not prices[item]or p<prices[item]then prices[item]=p end end
  end
  for item,price in pairs(prices)do E.Observe(item,price)end
 end
end
local function summary(r)
 if not r then return 'Select an item recipe to calculate crafting profit.'end
 local recipe=r.recipe;local title=recipe.name or E.Item(recipe.itemID).name or ('Item '..recipe.itemID)
 local lines={title..' — '..recipe.quantity..' item(s) per craft',
  'Crafting materials: '..(r.cost and ForeverAssistMoney(r.cost)or 'Unknown'),
  'Vendor sale: '..(r.vendor and ForeverAssistMoney(r.vendor)or 'Unknown')..'  |  Profit: '..money(r.vendorProfit),
  'AH sale: '..(r.sale and ForeverAssistMoney(r.sale)or 'Unknown'),
  'AH cut ('..(settings().craftAuctionCut or 5)..'%): '..(r.tax and ForeverAssistMoney(r.tax)or 'Unknown'),
  'Deposit '..(r.depositEstimated and '(estimate)'or '(API)')..': '..(r.deposit and ForeverAssistMoney(r.deposit)or 'Unknown'),
  'After costs, cut and deposit: '..money(r.profit),
  'Successful sale (deposit refunded): '..money(r.successProfit)}
 if r.source then lines[#lines+1]='Price: '..r.source..(r.age and (' — %.1f days old'):format(r.age/86400)or ' — age unavailable')end
 if #r.missing>0 then lines[#lines+1]='Missing prices: '..table.concat(r.missing,', ')end
 if recipe.variable then lines[#lines+1]='Variable yield: minimum output used'end
 if r.notAuctionable then lines[#lines+1]='Output is bound; no AH profit'end
 return table.concat(lines,'\n')
end
local function inlineSummary(r)
 if not r then return 'Crafting profit\nSelect an item recipe.'end
 local cash=function(v)return v and ForeverAssistMoney(v)or 'Unknown'end
 return table.concat({'Mats: '..cash(r.cost)..'  |  Vendor: '..cash(r.vendor),
  'Vendor profit: '..money(r.vendorProfit),
  'AH net: '..money(r.profit),
  'Cut: '..cash(r.tax)..'  |  Deposit'..(r.depositEstimated and ' (est.)'or '')..': '..cash(r.deposit)},'\n')
end
local function rowRecipe(row,trainer,legacy)
 local data=row.GetElementData and row:GetElementData()or row.elementData
 local info=data and (data.recipeInfo or data)
 if not trainer and info and info.recipeID then return E.Recipe(info.recipeID)end
 local index=info and info.skillIndex or row.skillIndex or row.index or row.GetID and row:GetID()
 if not num(index)or index<1 then return end
 if not trainer then return E.LegacyRecipe(index,legacy==CraftFrame)end
 return E.TrainerRecipe(index)
end
function E.DecorateRows(host)
 local trainer=host==ClassTrainerFrame
 local function annotate(row)
  local r=rowRecipe(row,trainer,host);local result=r and E.Estimate(r)
  if not row.faProfit then row.faProfit=row:CreateFontString(nil,'OVERLAY','TrailboundSmall');row.faProfit:SetPoint('RIGHT',row,'RIGHT',-4,0);row.faProfit:SetWidth(95);row.faProfit:SetJustifyH('RIGHT')end
  row.faProfit:SetText(settings().craftProfit~=false and result and money(result.profit)or '');row.faProfit:SetFont(STANDARD_TEXT_FONT,10,'OUTLINE')
 end
 local list=host.CraftingPage and host.CraftingPage.RecipeList or host.RecipeList or host
 local box=list.ScrollBox or host.ScrollBox
 if box and box.ForEachFrame then box:ForEachFrame(annotate)end
 local prefix=trainer and 'ClassTrainerSkill'or host==CraftFrame and 'Craft'or 'TradeSkillSkill'
 for i=1,30 do local row=_G[prefix..i];if row and row:IsShown()then annotate(row)end end
end
function E.Refresh()
 if not account then return end
 for _,host in ipairs({ProfessionsFrame or false,TradeSkillFrame or false,CraftFrame or false,ClassTrainerFrame or false})do
  if host and host:IsShown()then
   local p=panels[host]
   if not p then
    local embedded=host~=ClassTrainerFrame
    local parent=embedded and (host.CraftingPage or host)or host
    p=CreateFrame('Frame',nil,parent,'BackdropTemplate');p.embedded=embedded;p:SetClampedToScreen(false);p:EnableMouse(true)
    if embedded then p:SetSize(math.min(340,math.max(240,host:GetWidth()-440)),110);p:SetPoint('BOTTOMRIGHT',parent,'BOTTOMRIGHT',-18,64)
    else p:SetSize(340,132);p:SetPoint('TOPLEFT',host,'TOPRIGHT',8,-5)end
    p:SetBackdrop({bgFile='Interface/Buttons/WHITE8X8',edgeFile='Interface/Buttons/WHITE8X8',edgeSize=1});p:SetBackdropColor(.10,.065,.035,.97);p:SetBackdropBorderColor(.6,.48,.31,1)
    p.text=p:CreateFontString(nil,'OVERLAY','TrailboundSmall');p.text:SetPoint('TOPLEFT',9,-8);p.text:SetWidth(p:GetWidth()-18);p.text:SetJustifyH('LEFT');p.text:SetFont(STANDARD_TEXT_FONT,10,'OUTLINE');p.text:SetMaxLines(embedded and 4 or 5);p.text:SetHeight(embedded and 62 or 84)
    p.search=CreateFrame('Button',nil,p,'UIPanelButtonTemplate');p.search:SetSize((p:GetWidth()-28)/2,20);p.search:SetPoint('BOTTOMLEFT',9,7);p.search:SetText('Search mats');p.search:SetScript('OnClick',function()E.SearchMats(p.recipe)end);ForeverAssistStyleButton(p.search)
    local b=CreateFrame('Button',nil,p,'UIPanelButtonTemplate');b:SetSize((p:GetWidth()-28)/2,20);b:SetPoint('BOTTOMRIGHT',-9,7);b:SetText('Settings');b:SetScript('OnClick',E.Options);ForeverAssistStyleButton(b)
    p:SetScript('OnEnter',function(self)if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');for line in (self.details or ''):gmatch('[^\n]+')do GameTooltip:AddLine(line,1,1,1,true)end;GameTooltip:Show()end end)
    p:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
    panels[host]=p
   end
   local recipe,index=E.CurrentRecipe(host);p.recipe=recipe
   local result=recipe and E.Estimate(recipe);local text=summary(result)
   local feeLine=''
   if host==ClassTrainerFrame and index then local fee=call(GetTrainerServiceCost,index);if num(fee)then feeLine='\nLearning fee: '..ForeverAssistMoney(fee);text=text..feeLine..' (one-time)'end end
   p.details=text;p.text:SetText(inlineSummary(result)..feeLine);p.search:SetEnabled(recipe~=nil);p:SetShown(settings().craftProfit~=false);E.DecorateRows(host)
  end
 end
end
function E.Options()
 if not options then
  options=CreateFrame('Frame','ForeverAssistProfitOptions',UIParent,'BackdropTemplate');options:SetSize(490,550)
  local title=options:CreateFontString(nil,'OVERLAY','TrailboundTitle');title:SetPoint('TOPLEFT',20,-20);title:SetText('Crafting profit estimates')
  local c=CreateFrame('CheckButton',nil,options,'UICheckButtonTemplate');c:SetPoint('TOPLEFT',20,-65);local t=c:CreateFontString(nil,'OVERLAY','TrailboundText');t:SetPoint('LEFT',c,'RIGHT',2,0);t:SetText('Show crafting and trainer profit panels');c:SetScript('OnClick',function(self)settings().craftProfit=self:GetChecked()and true or false;E.Refresh()end);c:HookScript('OnShow',function(self)self:SetChecked(settings().craftProfit~=false)end)
  local sources={'Auto','Memory','Auctionator','TSM'}
  local function button(label,y,fn,caption)
   local b=CreateFrame('Button',nil,options,'UIPanelButtonTemplate');b:SetSize(420,26);b:SetPoint('TOPLEFT',20,y);b:SetScript('OnClick',function()fn();b:SetText(caption());E.Refresh()end);b:HookScript('OnShow',function()b:SetText(caption())end);ForeverAssistStyleButton(b)
  end
  button('source',-120,function()local n=1;for i,s in ipairs(sources)do if s==(settings().craftPriceSource or 'Auto')then n=i end end;settings().craftPriceSource=sources[n%#sources+1]end,function()return 'Price source: '..(settings().craftPriceSource or 'Auto')end)
  button('cut',-160,function()settings().craftAuctionCut=(settings().craftAuctionCut or 5)==5 and 15 or 5 end,function()return 'AH cut: '..(settings().craftAuctionCut or 5)..'% (click: faction / neutral)'end)
  button('deposit',-200,function()settings().craftDepositPercent=(settings().craftDepositPercent or 15)==15 and 75 or 15 end,function()return 'Estimated 12h deposit: '..(settings().craftDepositPercent or 15)..'% of vendor value'end)
  button('duration',-240,function()settings().craftAuctionDuration=(settings().craftAuctionDuration or 1)%3+1 end,function()return 'Listing duration: '..({12,24,48})[settings().craftAuctionDuration or 1]..' hours'end)
  button('age',-280,function()settings().craftPriceMaxDays=({[14]=7,[7]=3,[3]=1,[1]=14})[settings().craftPriceMaxDays or 14]end,function()return 'Ignore remembered prices older than '..(settings().craftPriceMaxDays or 14)..' days'end)
  local help=options:CreateFontString(nil,'OVERLAY','TrailboundText');help:SetPoint('TOPLEFT',20,-335);help:SetWidth(440);help:SetJustifyH('LEFT');help:SetText('Auto: Auctionator, then TSM dbmarket, then your observed AH prices. Open AH searches to build memory. Vendor reagent costs are learned at merchants.\n\nAll materials count even when already owned. Unknown inputs never count as free. Deposits use the API where available, otherwise the labeled vendor-value estimate above. Successful sales refund the deposit. AH prices are estimates, not guaranteed sales.\n\nSearch mats queues every required material and runs when the AH is open. Trainer recipes need readable recipe data or a previously cached matching schematic.');options:Hide()
 end
 ForeverAssistShowEditor(options)
end
function E.Initialize(a,get)
 account,settings=a,get;account.auctionMemory=account.auctionMemory or {};account.craftingRecipes=account.craftingRecipes or {};account.merchantPrices=account.merchantPrices or {}
 E.sessionRecipes={}
 E.Refresh()
end
local frame=CreateFrame('Frame')
for _,event in ipairs({'TRADE_SKILL_SHOW','TRADE_SKILL_LIST_UPDATE','TRADE_SKILL_DATA_SOURCE_CHANGED','TRAINER_SHOW','TRAINER_UPDATE','ADDON_LOADED','GET_ITEM_INFO_RECEIVED','AUCTION_HOUSE_SHOW','AUCTION_HOUSE_CLOSED','COMMODITY_SEARCH_RESULTS_UPDATED','ITEM_SEARCH_RESULTS_UPDATED','AUCTION_HOUSE_BROWSE_RESULTS_UPDATED','AUCTION_HOUSE_BROWSE_RESULTS_ADDED','AUCTION_ITEM_LIST_UPDATE','AUCTION_HOUSE_THROTTLED_SYSTEM_READY','MERCHANT_SHOW'})do pcall(frame.RegisterEvent,frame,event)end
frame:SetScript('OnEvent',function(_,event,id)
 if not account then return end
 if event=='TRADE_SKILL_LIST_UPDATE'or event=='TRADE_SKILL_DATA_SOURCE_CHANGED'or event=='GET_ITEM_INFO_RECEIVED'then E.sessionRecipes={}end
 if event=='MERCHANT_SHOW'and GetMerchantNumItems and GetMerchantItemInfo then
  for i=1,GetMerchantNumItems()do local values={pcall(GetMerchantItemInfo,i)};local item=itemID(call(GetMerchantItemLink,i));local price,qty,extended=values[4],values[5],values[8];if item and num(price)and num(qty)and qty>0 and not extended then account.merchantPrices[item]=price/qty end end
 elseif event=='AUCTION_HOUSE_SHOW'then if C_Timer and C_Timer.After then C_Timer.After(.5,E.SearchPending)else E.SearchPending()end
 elseif event=='AUCTION_HOUSE_CLOSED'then E.nativeSearch=nil
 else
  E.CaptureMarket(event,id)
  if E.nativeSearch and E.nativeSearch.waiting and (event=='AUCTION_HOUSE_BROWSE_RESULTS_UPDATED'or event=='AUCTION_ITEM_LIST_UPDATE')then E.nativeSearch.waiting=false;E.nativeSearch.index=E.nativeSearch.index+1 end
  if E.nativeSearch and not E.nativeSearch.waiting then E.SearchNext()end
 end
 E.Refresh()
end)
local elapsed=0;frame:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if account and elapsed>=.75 then elapsed=0
 if E.nativeSearch and E.nativeSearch.waiting and E.nativeSearch.started and GetTime()-E.nativeSearch.started>20 then E.nativeSearch=nil;print('|cffd2b077Trailbound:|r Material search timed out. Click Search mats to retry.')end
 if ProfessionsFrame and ProfessionsFrame:IsShown()or TradeSkillFrame and TradeSkillFrame:IsShown()or CraftFrame and CraftFrame:IsShown()or ClassTrainerFrame and ClassTrainerFrame:IsShown()then E.Refresh()end
end end)
