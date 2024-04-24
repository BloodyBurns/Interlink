type Task = {
	callback: () -> any,
	args: {any},
	retries: number,
};

type TaskManager = {
	tasks: {[string]: Task},
	results: {[string]: any},
	errors: {[string]: string},
	failedTasks: {[string]: Task},
	fetchResults: (self: TaskManager) -> {[string]: any},
	fetchErrors: (self: TaskManager) -> {[string]: string},
	append: (self: TaskManager, string, () -> any, ...any) -> (),
	execute: (self: TaskManager, string) -> (boolean),
	executeAll: (self: TaskManager, {string}?) -> ({[string]: string}),
	retryFailedTasks: (self: TaskManager) -> ()
};

local Parallel = {};
Parallel.__index = Parallel;
function Parallel.new(): TaskManager
	return setmetatable({
		tasks = {},
		results = {},
		errors = {},
		failedTasks = {},
	}, {__index = {
		fetchErrors = function(self) return self.errors end,
		fetchResults = function(self) return self.results end,
		append = function(self, key, callback, ...) self.tasks[key] = {callback = callback, args = {...}, retries = 0} end,
		execute = function(self, key)
			if not self.tasks[key] then return end --> Nonexisting task

			local taskData = self.tasks[key];
			local status, result = pcall(taskData.callback, table.unpack(taskData.args));

			if status then
				self.results[key] = result;
				self.failedTasks[key] = nil;
				print(string.format('Successfully executed task -> \'%s\' [%d/3]', key, taskData.retries));
				return true;
			end

			taskData.retries += 1;
			self.errors[key] = result;
			self.failedTasks[key] = taskData;
			print(string.format('Failed to execute task -> \'%s\' [%d/3]', key, taskData.retries - 1));
			return false;
		end,

		executeAll = function(self, exclude)
			for key in self.tasks do
				if not exclude or not table.find(exclude, key) then
					task.spawn(self.execute, self, key)
				end
			end
		end,

		retryFailedTasks = function(self)
			if not next(self.failedTasks) then return end --> No failed tasks
			for key, taskData in self.failedTasks do
				if taskData.retries > 3 then self.failedTasks[key] = nil; print(string.format('Task -> \'%s\' has reached max retry attempts. Terminating task...', key)) continue end --> Max retry attempts reached
				self:execute(key);
			end
		end
	}});
end

--[[=[
  -->| Example Usage
  local Interlink = Parallel.new();
  local Debris = game:GetService('Debris');
  local PlayerGui = game:GetService('Players').LocalPlayer.PlayerGui;
  local Panel = (function()
  	local Panel = Instance.new('ScreenGui');
  	local Button = Instance.new('TextButton');
  	local ImageLabel = Instance.new('ImageLabel');
  	local UICorner = Instance.new('UICorner');
  
  	Panel.Name = 'Panel';
  	Panel.Parent = PlayerGui;
  
  	Button.Name = 'Button';
  	Button.Parent = Panel;
  	Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0);
  	Button.BackgroundTransparency = 0.100;
  	Button.BorderColor3 = Color3.fromRGB(0, 0, 0);
  	Button.BorderSizePixel = 0;
  	Button.Position = UDim2.new(0.447, 0, 0.38, 0);
  	Button.Size = UDim2.new(0, 200, 0, 50);
  	Button.Font = Enum.Font.SourceSansSemibold;
  	Button.Text = 'Retry Failed Tasks';
  	Button.TextColor3 = Color3.fromRGB(255, 255, 255);
  	Button.TextSize = 20.000;
  	Button.TextWrapped = true;
  
  	ImageLabel.Name = ' ';
  	ImageLabel.Parent = Button;
  	ImageLabel.AnchorPoint = Vector2.new(0.5, 0.5);
  	ImageLabel.BackgroundTransparency = 1.000;
  	ImageLabel.BorderSizePixel = 0;
  	ImageLabel.Position = UDim2.new(0.5, 0, 0.5, 0);
  	ImageLabel.Size = UDim2.new(1, 47, 1, 47);
  	ImageLabel.ZIndex = 0;
  	ImageLabel.Image = 'rbxassetid://6014261993';
  	ImageLabel.ImageColor3 = Color3.fromRGB(0, 0, 0);
  	ImageLabel.ImageTransparency = 0.800;
  	ImageLabel.ScaleType = Enum.ScaleType.Slice;
  	ImageLabel.SliceCenter = Rect.new(49, 49, 450, 450);
  
  	UICorner.Name = ' ';
  	UICorner.Parent = Button;
  	return Panel;
  end)();
  
  local retryEvent = Panel.Button.MouseButton1Click:Connect(function()
  	if next(Interlink:fetchErrors()) then
  		Interlink:retryFailedTasks();
  	end
  end);
  
  Interlink:append('task1', function() workspace.InsertedPartByClientTest:Destroy(); end);
  Interlink:append('task2', function() print('task ranned with no problems'); end);
  Interlink:executeAll();
  
  if not next(Interlink:fetchErrors()) then Panel.Button.Visible = false; end
  
  task.wait(5);
  
  local testPart = Instance.new('Part');
  testPart.Name = 'InsertedPartByClientTest';
  testPart.Parent = workspace;
  Debris:AddItem(testPart, 10);
  Debris:AddItem(Panel, 10);
  
  task.wait(10);
  warn('cleaning up');
  retryEvent:Disconnect();
  Interlink = nil;
]=]

return Parallel;
