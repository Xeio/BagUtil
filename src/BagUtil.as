import xeio.Utils;
import com.GameInterface.DistributedValue;
import com.GameInterface.DistributedValueBase;
import com.GameInterface.InventoryItem;
import com.GameInterface.Game.Character;
import com.GameInterface.ShopInterface;
import com.Utils.LDBFormat;
import flash.geom.Point;
import mx.utils.Delegate;
import com.Utils.Text;
import com.Utils.Archive;

import com.GameInterface.Game.CharacterBase;
import com.GameInterface.Inventory;


class BagUtil
{    
	private var m_swfRoot: MovieClip;
	
    private var m_openDropdownButton:MovieClip;
    private var m_stopOpeningButton:MovieClip;
    private var m_sellButton:MovieClip;
    private var m_openDropdownButtons:Array;
    private var m_sellRightDropdownButtons:Array;
    private var m_sellDropdownButtons:Array;
	
	private var m_openBagsCommand:DistributedValue;
	private var m_sellItemsCommand:DistributedValue;
	
	private var m_Inventory:Inventory;
	private var m_OpenShop:ShopInterface;
	private var m_OpenBagsValue:String;
	private var m_itemSellCount:Number = 0;
	private var m_itemsToSell:Array = [];
	private var m_itemsToOpen:Array = [];
	private var m_storedSignalListeners:Array;
	private var m_storedTokenTotals:Array;
    private var m_resetListsFunction:Function;
    private var m_LayoutFunction:Function;
	
	static var TALISMAN_BAGS:Array = [LDBFormat.LDBGetText(50200, 9264943)];
	static var WEAPON_BAGS:Array = [LDBFormat.LDBGetText(50200, 9289681)];
	static var GLYPH_BAGS:Array = [LDBFormat.LDBGetText(50200, 7719874), LDBFormat.LDBGetText(50200, 9284361)];
    static var CONTAINER_KEYS:Array = [LDBFormat.LDBGetText(50200, 9338616)];
    
    static var CONTAINER_CLOTHING:Array = [
    LDBFormat.LDBGetText(50200, 9339631), LDBFormat.LDBGetText(50200, 9339634), LDBFormat.LDBGetText(50200, 9339639), //Shirt
    LDBFormat.LDBGetText(50200, 9339642), LDBFormat.LDBGetText(50200, 9339644), LDBFormat.LDBGetText(50200, 9339646), //Pants+Skirt
    LDBFormat.LDBGetText(50200, 9339653), LDBFormat.LDBGetText(50200, 9339655), LDBFormat.LDBGetText(50200, 9339663)  //Sneakers
    ];
    
    static var CONTAINER_JUNK:Array = [
        LDBFormat.LDBGetText(50200, 9338918), //The Mistress's Bashosen
        LDBFormat.LDBGetText(50200, 9338745), //Primeval Jötunn Cranial Fragment
        LDBFormat.LDBGetText(50200, 9338727), //True Ancile of the Salii
        LDBFormat.LDBGetText(50200, 9339531), //Kris Setan Kober
        LDBFormat.LDBGetText(50200, 9338829), //Shard of Sessho-seki
        LDBFormat.LDBGetText(50200, 9339702), //Asibikaashi's Hoop
        LDBFormat.LDBGetText(50200, 9338717), //Ningishzida's Rod
        LDBFormat.LDBGetText(50200, 9338843), //Ausadhirdipyamanas Seeds
        LDBFormat.LDBGetText(50200, 9339630), //Ring of Mudarra
        LDBFormat.LDBGetText(50200, 9337459), //Boincan Flask
        LDBFormat.LDBGetText(50200, 9338845) //Preta
    ];
    
    static var KRAMPUS_ROCKETS:Array = [LDBFormat.LDBGetText(50200, 8396933)];
    static var KRAMPUS_PRESENTS:Array = [LDBFormat.LDBGetText(50200, 8396874), LDBFormat.LDBGetText(50200, 8396885), LDBFormat.LDBGetText(50200, 8397420)];
    static var ANNIVERSARY_FLARES:Array = [LDBFormat.LDBGetText(50200, 8262189)];
    static var THIRD_AGE_BAGS:Array = [LDBFormat.LDBGetText(50200, 9290325)];
	
	public static function main(swfRoot:MovieClip):Void 
	{
		var bagUtil = new BagUtil(swfRoot);
		
		swfRoot.onLoad = function() { bagUtil.OnLoad(); };
		swfRoot.OnUnload =  function() { bagUtil.OnUnload(); };
		swfRoot.OnModuleActivated = function(config:Archive) { bagUtil.Activate(config); };
		swfRoot.OnModuleDeactivated = function() { return bagUtil.Deactivate(); };
	}
	
    public function BagUtil(swfRoot: MovieClip) 
    {
		m_swfRoot = swfRoot;
    }
	
	public function OnLoad()
	{
        m_openDropdownButtons = [];
        m_sellRightDropdownButtons = [];
        m_sellDropdownButtons = [];
        
		var clientCharacterInstanceID:Number = CharacterBase.GetClientCharID().GetInstance();
        
        m_Inventory = new Inventory(new com.Utils.ID32(_global.Enums.InvType.e_Type_GC_BackpackContainer, clientCharacterInstanceID));
        m_Inventory.SignalItemAdded.Connect(OnSignalItemAdded, this)
        
		m_openBagsCommand = DistributedValue.Create("BagUtil_OpenBags");
		m_openBagsCommand.SetValue(undefined);
		m_openBagsCommand.SignalChanged.Connect(OpenBagsCommand, this);
		
		m_sellItemsCommand = DistributedValue.Create("BagUtil_SellItems");
		m_sellItemsCommand.SetValue(undefined);
		m_sellItemsCommand.SignalChanged.Connect(SellItemsCommand, this);
		
		ShopInterface.SignalOpenShop.Connect(OnOpenShop, this);
		
		//Delay adding the buttons slightly, in case we load before the inventory
		setTimeout(Delegate.create(this, AddInventoryButtons), 1000);
	}
	
	public function OnUnload()
	{
		m_openDropdownButton.removeMovieClip(); 
		m_openDropdownButton = undefined;
        var button;
        while (button = m_openDropdownButtons.pop())
        {
            button.removeMovieClip();
        }
        while (button = m_sellDropdownButtons.pop())
        {
            button.removeMovieClip();
        }
        while (button = m_sellRightDropdownButtons.pop())
        {
            button.removeMovieClip();
        }
		m_stopOpeningButton.removeMovieClip();
		m_stopOpeningButton = undefined;
		m_sellButton.removeMovieClip();
		m_sellButton = undefined;
		
		ShopInterface.SignalOpenShop.Disconnect(OnOpenShop, this);
		if (m_OpenShop != undefined)
		{
			m_OpenShop.SignalCloseShop.Disconnect(OnCloseShop, this);
		}
		
        m_Inventory.SignalItemAdded.Disconnect(OnSignalItemAdded, this);
		m_openBagsCommand.SignalChanged.Disconnect(OpenBagsCommand, this);
		m_sellItemsCommand.SignalChanged.Disconnect(SellItemsCommand, this);
	}
	
	public function Activate(config: Archive)
	{
	}
	
	public function Deactivate(): Archive
	{
		var archive: Archive = new Archive();			
		return archive;
	}
	
	private function AddInventoryButtons()
	{
		var x = _root.backpack2.InvBackground0.m_BottomBar;
		
		var btnWidth = 65;
		
		m_openDropdownButton = CreateButton(x, "m_openButton", btnWidth, 5, 0, "Open...", true);
		m_openDropdownButton.onMousePress = Delegate.create(this, OpenButtonPress);
		
        AddOpenDropdownButton(x, "Keys", btnWidth, "key");
        AddOpenDropdownButton(x, "Weapons", btnWidth, "weapon");
        AddOpenDropdownButton(x, "Talismans", btnWidth, "talisman");
        AddOpenDropdownButton(x, "Glyphs", btnWidth, "glyph");
        AddOpenDropdownButton(x, "All", btnWidth, "all");
		
		m_stopOpeningButton = CreateButton(x, "m_stopOpeningButton", btnWidth, 5, 0, "Stop", false);
		m_stopOpeningButton.onMousePress = Delegate.create(this, function() { this.m_openBagsCommand.SetValue("stop"); } );
        
		m_sellButton = CreateButton(x, "m_sellButton", 50, btnWidth + 10, 0, "Sell", false);
 		m_sellButton.onMousePress = Delegate.create(this, SellButtonPress);
        
        btnWidth = 170;
        AddOpenRightClickDropdownButton(x, "Destroy Clothing", btnWidth, DeleteContainerClothing);
        AddOpenRightClickDropdownButton(x, "Destroy Distillates", btnWidth, DeleteDistillates);
        AddOpenRightClickDropdownButton(x, "Opent Third Age Fragments", btnWidth, OpenThirdAgeFragments);
        var currentDate:Date = new Date();
        if ((currentDate.getMonth() == 11 && currentDate.getDate() > 8) || (currentDate.getMonth() == 0 && currentDate.getDate() < 5))
        {
            AddOpenRightClickDropdownButton(x, "Destroy Krampus", btnWidth, DeleteKrampusRockets);
        }
        if ((currentDate.getMonth() == 5 && currentDate.getDate() > 19) || (currentDate.getMonth() == 6 && currentDate.getDate() < 12))
        {
            AddOpenRightClickDropdownButton(x, "Destroy Flares", btnWidth, DeleteAnniversaryFlares);
        }
        
        AddSellRightClickDropdownButton(x, "Container Junk", 100, SellContainerJunk);
	}
    
    private function OpenButtonPress(buttonIndex:Number)
    {
        if (buttonIndex == 1)
        {
            SetOpenDropdownVisible(!this.m_openDropdownButtons[0]._visible);
            SetOpenRightClickDropdownVisible(false);
        }
        else if (buttonIndex == 2)
        {
            SetOpenRightClickDropdownVisible(!this.m_sellRightDropdownButtons[0]._visible);
            SetOpenDropdownVisible(false);
        }
    }
    
    private function SellButtonPress(buttonIndex:Number)
    {
        if (buttonIndex == 1)
        {
            this.m_sellItemsCommand.SetValue(true);
            SetSellDropdownVisible(false);
        }
        else if (buttonIndex == 2)
        {
            SetSellDropdownVisible(!this.m_sellDropdownButtons[0]._visible);
        }
    }
	
	private function ItemIsSafeToSell(item:InventoryItem):Boolean
	{
		if (item.m_Pips != 1 && item.m_Pips != 2) return false; //Only include 1 or 2 pip items
		if (item.m_Rarity != 2) return false; //Non-commons
		if (item.m_Rank != 1) return false; //Only include items at rank 1 (unranked)
		if (item.m_XP != 0) return false; //XP (mostly redundant with rank for commons)
		if (item.m_IsBoundToPlayer) return false; //Bound items
		return true;
	}
    
    private function ItemIsContainerJunk(item:InventoryItem):Boolean
	{
        if (item.m_IsBoundToPlayer) return false; //Bound items
        if (!Utils.Contains(CONTAINER_JUNK, item.m_Name)) return false;
		if (item.m_Rarity != 4 && item.m_Rarity != 5) return false; //Yellow or Purple junk only
		return true;
	}
	
	private function ItemIsExtraordinary(item:InventoryItem)
	{
		//ColorLine = 43 Extraordinary items (red background?)
		return item.m_ColorLine == 43;
	}
		
	function OnOpenShop(shopInterface:ShopInterface)
	{
		m_OpenShop = shopInterface;
		m_OpenShop.SignalCloseShop.Connect(OnCloseShop, this);
		m_sellButton._visible = true;
	}

	function OnCloseShop()
	{
		m_OpenShop = undefined;
		m_sellButton._visible = false;
        SetSellDropdownVisible(false);
	}
    
    function SellContainerJunk()
    {
        SetSellDropdownVisible(false);
        BuildContainerJunkSellList();
        PreSellSetup();
        SellItems();
    }
	
	function SellItemsCommand()
	{
		var value = m_sellItemsCommand.GetValue();
		if (value != undefined)
		{
			m_sellItemsCommand.SetValue(undefined);
			BuildSellList();
			PreSellSetup();
			setTimeout(Delegate.create(this, SellItems), 500);
		}
	}
    
    private function PreSellSetup()
    {
        if (m_storedSignalListeners) return;
        
        //It's slow to have all the currency listeners trigger while selling, so just... stop them... for now.
        var character:Character = Character.GetCharacter(CharacterBase.GetClientCharID());
        m_storedSignalListeners = character.SignalTokenAmountChanged["m_EventList"];
        character.SignalTokenAmountChanged["m_EventList"] = new Array();
        m_storedTokenTotals = new Array();
        character.SignalTokenAmountChanged.Connect(SlotTokenChanged, this);
        m_resetListsFunction = _root.shopcontroller.m_Window.m_Content.ResetList;
        _root.shopcontroller.m_Window.m_Content.ResetList = undefined;
        m_LayoutFunction = _root.shopcontroller.m_Window.m_Content.Layout;
        _root.shopcontroller.m_Window.m_Content.Layout = undefined;
    }
	
	private function SlotTokenChanged(tokenID:Number, newAmount:Number, oldAmount:Number)
	{
		//Store any currency events to fire at the end of the sell action
		if (!m_storedTokenTotals[tokenID])
		{
			m_storedTokenTotals[tokenID] = new Object();
			m_storedTokenTotals[tokenID].oldAmount = oldAmount;
		}
		m_storedTokenTotals[tokenID].newAmount = newAmount;
	}
	
	function BuildSellList()
	{
		var defaultBag/*:ItemIconBox*/ = _root.backpack2.m_IconBoxes[0];
		for (var i:Number = 0; i < defaultBag.GetNumRows(); i++)
		for (var j:Number = 0; j < defaultBag.GetNumColumns(); j++)
		{
			var item:InventoryItem = defaultBag.GetItemAtGridPosition(new Point(j, i)).GetData();
			
			if (item != undefined && ItemIsSafeToSell(item, false))
			{
				if (ItemIsExtraordinary(item))
				{
					//Extraordinaries go to the end of the list rather than the start so they sell last
					m_itemsToSell.push(item);
				}
				else
				{
					m_itemsToSell.unshift(item);
				}
			}
		}
		m_itemSellCount = m_itemsToSell.length;
	}
    
    function BuildContainerJunkSellList()
    {
        var defaultBag/*:ItemIconBox*/ = _root.backpack2.m_IconBoxes[0];
        for (var i:Number = 0; i < defaultBag.GetNumRows(); i++)
        for (var j:Number = 0; j < defaultBag.GetNumColumns(); j++)
        {
            var item:InventoryItem = defaultBag.GetItemAtGridPosition(new Point(j, i)).GetData();

            if (item != undefined && ItemIsContainerJunk(item))
            {
                m_itemsToSell.push(item);
            }
        }
        m_itemSellCount = m_itemsToSell.length;
    }
	
	function SellItems()
	{
		var item:InventoryItem = InventoryItem(m_itemsToSell.shift());
		if (item && m_OpenShop)
		{
			m_OpenShop.SellItem(m_Inventory.GetInventoryID(), item.m_InventoryPos);
			setTimeout(Delegate.create(this, SellItems), 50);
		}
		else
		{
            var character:Character = Character.GetCharacter(CharacterBase.GetClientCharID());
            if (m_storedSignalListeners)
            {
                //Restore the token change signals, and emit the "final" change values
                _root.shopcontroller.m_Window.m_Content.ResetList = m_resetListsFunction;
                _root.shopcontroller.m_Window.m_Content.Layout = m_LayoutFunction;                
                character.SignalTokenAmountChanged["m_EventList"] = m_storedSignalListeners;
                m_storedSignalListeners = undefined;
            }
			for (var tokenType in m_storedTokenTotals)
			{
				character.SignalTokenAmountChanged.Emit(tokenType, m_storedTokenTotals[tokenType].newAmount, m_storedTokenTotals[tokenType].oldAmount);
			}
			
			var sellTotal = (m_storedTokenTotals[_global.Enums.Token.e_Cash].newAmount - m_storedTokenTotals[_global.Enums.Token.e_Cash].oldAmount) || 0;
			com.GameInterface.Chat.SignalShowFIFOMessage.Emit("Sold " + m_itemSellCount + " item(s) for " + Text.AddThousandsSeparator(sellTotal) + " " + LDBFormat.LDBGetText("Tokens", "Token" + _global.Enums.Token.e_Cash) + ".", 0);
			
			if (m_itemSellCount > 0)
			{
				com.GameInterface.Game.Character.GetClientCharacter().AddEffectPackage("sound_fxpackage_GUI_trade_success.xml");
			}
		}
	}
	
	function OpenBagsCommand()
	{
		var value:String = m_openBagsCommand.GetValue();
		if (value != undefined)
		{
			m_OpenBagsValue = value.toLowerCase();
			m_openBagsCommand.SetValue(undefined);
            if (m_OpenBagsValue != "stop")
            {
                SetOpenDropdownVisible(false);
                SetStopOpeningVisible(true);
                
                OpenBags();    
            }
		}
	}
    
	private function ShouldOpenItem(item:InventoryItem):Boolean
	{
		if ((m_OpenBagsValue == "all" || m_OpenBagsValue == "weapon") && Utils.Contains(WEAPON_BAGS, item.m_Name))
		{
			return true;
		}
		if ((m_OpenBagsValue == "all" || m_OpenBagsValue == "talisman") && Utils.Contains(TALISMAN_BAGS, item.m_Name))
		{
			return true;
		}
		if ((m_OpenBagsValue == "all" || m_OpenBagsValue == "glyph") && Utils.Contains(GLYPH_BAGS, item.m_Name))
		{
			return true;
		}
        if ((m_OpenBagsValue == "all" || m_OpenBagsValue == "key") && Utils.Contains(CONTAINER_KEYS, item.m_Name))
		{
			return true;
		}
		return false;
	}
	
	function OpenBags()
	{
		if (m_Inventory.GetFirstFreeItemSlot() == -1)
		{
			OpenBagsEnded("Inventory full, stopping.");
			return;
		}
		if (m_OpenBagsValue == "stop")
		{
			OpenBagsEnded("Manually stopped opening.");
			return;
		}
		
		var continueOpening:Boolean = false;
		var defaultBag/*:ItemIconBox*/ = _root.backpack2.m_IconBoxes[0];
		for (var i:Number = 0; i < defaultBag.GetNumRows(); i++)
		for (var j:Number = 0; j < defaultBag.GetNumColumns(); j++)
		{
			var itemSlot = defaultBag.GetItemAtGridPosition(new Point(j, i));
			var item:InventoryItem = itemSlot.GetData();
			
			if (item != undefined && ShouldOpenItem(item))
			{
				if (!itemSlot.GetSlotMC().item.m_HasCooldown)
				{
					m_Inventory.UseItem(item.m_InventoryPos);
					setTimeout(Delegate.create(this, OpenBags), 200);
					return;
				}
				continueOpening = true;
			}
		}
		
		if (continueOpening)
		{
			setTimeout(Delegate.create(this, OpenBags), 200);
		}
		else
		{
			OpenBagsEnded("Open Complete.");
		}
	}
	
	function CreateButton(root, name:String, btnWidth:Number, offsetX:Number, offsetY:Number, text:String, visible:Boolean) : MovieClip
	{
		var btn = root.attachMovie("ChromeButtonDark", name, root.getNextHighestDepth(), {_x:root.m_TokenButton._x - btnWidth - offsetX, _y:root.m_TokenButton._y - offsetY});
		btn.disableFocus = true;
		btn.textField.text = text;
		btn._width = btnWidth;
		btn._visible = visible;
		return btn;
	}
	
	function OpenBagsEnded(reason:String)
	{
		com.GameInterface.Chat.SignalShowFIFOMessage.Emit(reason, 0);
		
		SetStopOpeningVisible(false);
	}
	
	function SetOpenDropdownVisible(open:Boolean)
	{
        for (var i = 0; i < m_openDropdownButtons.length; i++)
            m_openDropdownButtons[i]._visible = open;
	}
    
    function SetOpenRightClickDropdownVisible(open:Boolean)
	{
        for (var i = 0; i < m_sellRightDropdownButtons.length; i++)
            m_sellRightDropdownButtons[i]._visible = open;
	}
    
    function SetSellDropdownVisible(open:Boolean)
	{
        for (var i = 0; i < m_sellDropdownButtons.length; i++)
            m_sellDropdownButtons[i]._visible = open;
	}
	
	function SetStopOpeningVisible(visible:Boolean)
	{
        m_openDropdownButton._visible = !visible;
        m_stopOpeningButton._visible = visible;
	}
    
    function AddOpenDropdownButton(parent:MovieClip, text:String, width:Number, commandParameter:String)
    {
        var yOffset = 25 + m_openDropdownButtons.length * 25;
        var newButton = CreateButton(parent, "m_openDropdown"+parent.UID(), width, 5, yOffset, text, false);
        newButton.onMousePress = Delegate.create(this, function() { this.m_openBagsCommand.SetValue(commandParameter); } );
        m_openDropdownButtons.push(newButton);
        return newButton;
    }
    
    function AddOpenRightClickDropdownButton(parent:MovieClip, text:String, width:Number, onPress:Function)
    {
        var yOffset = 25 + m_sellRightDropdownButtons.length * 25;
        var newButton = CreateButton(parent, "m_openRightDropdown"+parent.UID(), width, 5, yOffset, text, false);
        newButton.onMousePress = Delegate.create(this, onPress);
        m_sellRightDropdownButtons.push(newButton);
        return newButton;
    }
    
    function AddSellRightClickDropdownButton(parent:MovieClip, text:String, width:Number, onPress:Function)
    {
        var yOffset = 25 + m_sellDropdownButtons.length * 25;
        var newButton = CreateButton(parent, "m_sellRightDropdown"+parent.UID(), width, 75, yOffset, text, false);
        newButton.onMousePress = Delegate.create(this, onPress);
        m_sellDropdownButtons.push(newButton);
        return newButton;
    }
    
    function DeleteContainerClothing()
    {
        SetOpenRightClickDropdownVisible(false);
        
        var defaultBag/*:ItemIconBox*/ = _root.backpack2.m_IconBoxes[0];
        for (var i:Number = 0; i < defaultBag.GetNumRows(); i++)
        for (var j:Number = 0; j < defaultBag.GetNumColumns(); j++)
        {
            var itemSlot = defaultBag.GetItemAtGridPosition(new Point(j, i));
            var item:InventoryItem = itemSlot.GetData();

            if (item != undefined && Utils.Contains(CONTAINER_CLOTHING, item.m_Name))
            {
                if (item.m_ItemTypeGUI == 57339111) //Sanity check that this is a clothing item we're about to delete
                {
                    m_Inventory.DeleteItem(item.m_InventoryPos);
                }
            }
        }
    }
    
    function DeleteKrampusRockets()
    {
        SetOpenRightClickDropdownVisible(false);
        
        DeleteItem(KRAMPUS_ROCKETS);
    }
    
    function DeleteAnniversaryFlares()
    {
        SetOpenRightClickDropdownVisible(false);
        
        DeleteItem(ANNIVERSARY_FLARES);
    }
    
    function DeleteItem(itemsToDelete:Array)
    {
        var defaultBag/*:ItemIconBox*/ = _root.backpack2.m_IconBoxes[0];
        for (var i:Number = 0; i < defaultBag.GetNumRows(); i++)
        for (var j:Number = 0; j < defaultBag.GetNumColumns(); j++)
        {
            var itemSlot = defaultBag.GetItemAtGridPosition(new Point(j, i));
            var item:InventoryItem = itemSlot.GetData();

            if (item != undefined && Utils.Contains(itemsToDelete, item.m_Name))
            {
                m_Inventory.DeleteItem(item.m_InventoryPos);
            }
        }
    }
    
    function OnSignalItemAdded(inventoryID:com.Utils.ID32, itemPos:Number)
    {
        var item:InventoryItem = m_Inventory.GetItemAt(itemPos);
        if (Utils.Contains(KRAMPUS_PRESENTS, item.m_Name))
        {
            if (item.m_Rarity == 3) //Sanity check this is blue
            {
                m_Inventory.UseItem(itemPos);
            }
        }
    }
    
    function DeleteDistillates()
    {
        SetOpenRightClickDropdownVisible(false);
        
        var defaultBag/*:ItemIconBox*/ = _root.backpack2.m_IconBoxes[0];
        for (var i:Number = 0; i < defaultBag.GetNumRows(); i++)
        for (var j:Number = 0; j < defaultBag.GetNumColumns(); j++)
        {
            var itemSlot = defaultBag.GetItemAtGridPosition(new Point(j, i));
            var item:InventoryItem = itemSlot.GetData();

            if (item != undefined)
            {
                if (item.m_Name.indexOf("stillat") != -1 && //Distillate check
                item.m_XP > 0 && //Additional distillate check
                item.m_Name.indexOf("Gereinigtes") == -1  && item.m_Name.indexOf("urifi") == -1) //Make sure it's not "purified"
                {                    
                    if (DistillateValueIsBelowThreshold(item))
                    {
                        m_Inventory.DeleteItem(item.m_InventoryPos);
                    }
                }
            }
        }
    }
    
    function DistillateValueIsBelowThreshold(item:InventoryItem) : Boolean
    {
        var maxToDelete: Number = DistributedValueBase.GetDValue("BagUtil_DistillateDeletionMax");
        if (maxToDelete > 0 && item.m_XP > 0 && maxToDelete >= item.m_XP)
        {
            return true;   
        }
        return false;
    }
    
    function OpenThirdAgeFragments()
    {
        var continueOpening:Boolean = false;
        var defaultBag/*:ItemIconBox*/ = _root.backpack2.m_IconBoxes[0];
        for (var i:Number = 0; i < defaultBag.GetNumRows(); i++)
        for (var j:Number = 0; j < defaultBag.GetNumColumns(); j++)
        {
            var itemSlot = defaultBag.GetItemAtGridPosition(new Point(j, i));
            var item:InventoryItem = itemSlot.GetData();

            if (item != undefined)
            {
                if (Utils.Contains(THIRD_AGE_BAGS, item.m_Name))
                {
                    if (!itemSlot.GetSlotMC().item.m_HasCooldown)
                    {
                        m_Inventory.UseItem(item.m_InventoryPos);
                        setTimeout(Delegate.create(this, OpenThirdAgeFragments), 400);
                        return;
                    }
                    continueOpening = true;
                }
            }
        }

        if (continueOpening)
        {
            setTimeout(Delegate.create(this, OpenThirdAgeFragments), 400);
        }
        else
        {
            OpenBagsEnded("All Third Age Fragment bags opened.");
        }
    }
}