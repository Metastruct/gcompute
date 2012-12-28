local self = GCompute.Editor.ViewTypes:CreateType ("Code")

function self:ctor (container)
	self.CodeEditor = vgui.Create ("GComputeCodeEditor", container)
	self.CodeEditor:GetDocument ():AddView (self)
	
	self.ClipboardTarget = GCompute.Editor.EditorClipboardTarget (self.CodeEditor)
	
	self.SavableProxy = GCompute.SavableProxy (self:GetDocument ())
	self.UndoRedoStackProxy = GCompute.UndoRedoStackProxy (self:GetDocument ():GetUndoRedoStack ())
	
	-- File Watching
	self.IgnoreFileChanges = false
	self.FileChangeNotificationBar = nil
	self.FileSystemWatcher = VFS.FileSystemWatcher ()
	self.FileSystemWatcher:AddEventListener ("Changed",
		function (_, file)
			if self.IgnoreFileChanges then return end
			self:CreateFileChangeNotificationBar ()
			self.FileChangeNotificationBar:SetVisible (true)
			self.FileChangeNotificationBar:SetText (file:GetDisplayPath () .. " has been modified by another program.")
		end
	)
	
	-- Document events
	self:GetSavable ():AddEventListener ("FileChanged",
		function (_, oldFile, file)
			self.FileSystemWatcher:RemoveFile (oldFile)
			self.FileSystemWatcher:AddFile (file)
			
			self:SetTitle (file and file:GetDisplayName () or self:GetSavable ():GetPath ())
			self:SetToolTipText (file and file:GetDisplayPath () or nil)
		end
	)
	self:GetSavable ():AddEventListener ("Reloaded",
		function (_)
			if not self.FileChangeNotificationBar then return end
			self.FileChangeNotificationBar:SetVisible (false)
		end
	)
	self:GetSavable ():AddEventListener ("Saving",
		function (_)
			self.IgnoreFileChanges = true
		end
	)
	self:GetSavable ():AddEventListener ("Saved",
		function (_)
			self.IgnoreFileChanges = false
		end
	)
	self:GetSavable ():AddEventListener ("UnsavedChanged",
		function (_, unsaved)
			self:SetIcon (unsaved and "icon16/page_red.png" or "icon16/page.png")
		end
	)
	
	self.CodeEditor:AddEventListener ("DocumentChanged",
		function (_, oldDocument, document)
			if oldDocument then
				oldDocument:RemoveView (self)
			end
			if document then
				document:AddView (self)
			end
			self.SavableProxy:SetSavable (document)
			self.UndoRedoStackProxy:SetUndoRedoStack (document and document:GetUndoRedoStack () or nil)
			self:DispatchEvent ("DocumentChanged", oldDocument, document)
		end
	)
	
	self:SetIcon ("icon16/page.png")
end

function self:dtor ()
	if not self:GetDocument () then return end
	self:GetDocument ():RemoveView (self)
	
	self.FileSystemWatcher:dtor ()
end

function self:GetCode ()
	return self.CodeEditor:GetText ()
end

function self:GetEditor ()
	return self.CodeEditor
end

function self:SetCode (code)
	self.CodeEditor:SetText (code)
end

function self:SetDocument (document)
	if not document then
		GCompute.Error ("Code:SetDocument : document is nil!")
	end
	self.CodeEditor:SetDocument (document)
end

-- Components
function self:GetClipboardTarget ()
	return self.ClipboardTarget
end

function self:GetDocument ()
	if not self.CodeEditor then return nil end
	if not self.CodeEditor:IsValid () then return nil end
	return self.CodeEditor:GetDocument ()
end

function self:GetSavable ()
	return self.SavableProxy
end

function self:GetUndoRedoStack ()
	return self.UndoRedoStackProxy
end

-- Persistance
function self:LoadSession (inBuffer)
	local title = inBuffer:String ()
	
	local document = self:GetDocumentManager ():GetDocumentById (inBuffer:String ())
	if document then
		self:GetEditor ():SetDocument (document)
	end
	self:SetTitle (title)
end

function self:SaveSession (outBuffer)
	outBuffer:String (self:GetTitle ())
	outBuffer:String (self:GetDocument () and self:GetDocument ():GetId () or "")
end

-- Internal, do not call
function self:CreateFileChangeNotificationBar ()
	GLib.PrintStackTrace ()
	if self.FileChangeNotificationBar then return end
	self.FileChangeNotificationBar = vgui.Create ("GComputeFileChangeNotificationBar", self:GetContainer ())
	self.FileChangeNotificationBar:SetVisible (false)
	self.FileChangeNotificationBar:AddEventListener ("VisibleChanged",
		function ()
			self:InvalidateLayout ()
		end
	)
	self.FileChangeNotificationBar:AddEventListener ("ReloadRequested",
		function ()
			self:GetDocument ():Reload ()
		end
	)
	self:InvalidateLayout ()
end

-- Event handlers
function self:PerformLayout (w, h)
	local y = 0
	
	if self.FileChangeNotificationBar and
	   self.FileChangeNotificationBar:IsVisible () then
		self.FileChangeNotificationBar:SetPos (0, 0)
		self.FileChangeNotificationBar:SetWide (w)
		y = y + self.FileChangeNotificationBar:GetTall ()
	end
	
	self:GetEditor ():SetPos (0, y)
	self:GetEditor ():SetSize (w, h - y)
end