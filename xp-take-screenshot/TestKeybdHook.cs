//Cheat Engine :: View topic - [C#] Static Keyboard Hook - 
//http://forum.cheatengine.org/viewtopic.php?t=192699&sid=d25bb4a9d48a3518bba28ec63d6510a2

using System;
using System.Diagnostics;
using System.Windows.Forms; //MessageBox
using System.Runtime.InteropServices;

namespace TestKeybdHook
{
    public static class Hook
    {
        //This class is based lightly off of the class found at the following website

        //http://blogs.msdn.com/toub/archive/2006/05/03/589423.aspx

        private static class API
        {
            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern IntPtr SetWindowsHookEx(
                int idHook,
                HookDel lpfn,
                IntPtr hMod,
                uint dwThreadId);

            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool UnhookWindowsHookEx(
                IntPtr hhk);

            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern IntPtr CallNextHookEx(
                IntPtr hhk,
                int nCode,
                IntPtr
                wParam,
                IntPtr lParam);

            [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern IntPtr GetModuleHandle(
                string lpModuleName);

        }

        public enum VK
        {
            //Keycodes recieved from this website:

            //http://delphi.about.com/od/objectpascalide/l/blvkc.htm

            //I've commented out the keys that I've never heard of--feel free to uncomment them if you wish
           
            VK_LBUTTON      = 0X01, //Left mouse
            VK_RBUTTON      = 0X02, //Right mouse
            //VK_CANCEL       = 0X03,
            VK_MBUTTON      = 0X04,
            VK_BACK         = 0X08, //Backspace
            VK_TAB          = 0X09,
            //VK_CLEAR        = 0X0C,
            VK_RETURN       = 0X0D, //Enter
            VK_SHIFT        = 0X10,
            VK_CONTROL      = 0X11, //CTRL
            //VK_MENU         = 0X12,
            VK_PAUSE        = 0X13,
            VK_CAPITAL      = 0X14, //Caps-Lock
            VK_ESCAPE       = 0X1B,
            VK_SPACE        = 0X20,
            VK_PRIOR        = 0X21, //Page-Up
            VK_NEXT         = 0X22, //Page-Down
            VK_END          = 0X23,
            VK_HOME         = 0X24,
            VK_LEFT         = 0X25,
            VK_UP           = 0X26,
            VK_RIGHT        = 0X27,
            VK_DOWN         = 0X28,
            //VK_SELECT       = 0X29,
            //VK_PRINT        = 0X2A,
            //VK_EXECUTE      = 0X2B,
            VK_SNAPSHOT     = 0X2C, //Print Screen
            VK_INSERT       = 0X2D,
            VK_DELETE       = 0X2E,
            //VK_HELP         = 0X2F,

            VK_0            = 0X30,
            VK_1            = 0X31,
            VK_2            = 0X32,
            VK_3            = 0X33,
            VK_4            = 0X34,
            VK_5            = 0X35,
            VK_6            = 0X36,
            VK_7            = 0X37,
            VK_8            = 0X38,
            VK_9            = 0X39,

            VK_A            = 0X41,
            VK_B            = 0X42,
            VK_C            = 0X43,
            VK_D            = 0X44,
            VK_E            = 0X45,
            VK_F            = 0X46,
            VK_G            = 0X47,
            VK_H            = 0X48,
            VK_I            = 0X49,
            VK_J            = 0X4A,
            VK_K            = 0X4B,
            VK_L            = 0X4C,
            VK_M            = 0X4D,
            VK_N            = 0X4E,
            VK_O            = 0X4F,
            VK_P            = 0X50,
            VK_Q            = 0X51,
            VK_R            = 0X52,
            VK_S            = 0X53,
            VK_T            = 0X54,
            VK_U            = 0X55,
            VK_V            = 0X56,
            VK_W            = 0X57,
            VK_X            = 0X58,
            VK_Y            = 0X59,
            VK_Z            = 0X5A,

            VK_NUMPAD0      = 0X60,
            VK_NUMPAD1      = 0X61,
            VK_NUMPAD2      = 0X62,
            VK_NUMPAD3      = 0X63,
            VK_NUMPAD4      = 0X64,
            VK_NUMPAD5      = 0X65,
            VK_NUMPAD6      = 0X66,
            VK_NUMPAD7      = 0X67,
            VK_NUMPAD8      = 0X68,
            VK_NUMPAD9      = 0X69,
           
            VK_SEPERATOR    = 0X6C, // | (shift + backslash)
            VK_SUBTRACT     = 0X6D, // -
            VK_DECIMAL      = 0X6E, // .
            VK_DIVIDE       = 0X6F, // /

            VK_F1           = 0X70,
            VK_F2           = 0X71,
            VK_F3           = 0X72,
            VK_F4           = 0X73,
            VK_F5           = 0X74,
            VK_F6           = 0X75,
            VK_F7           = 0X76,
            VK_F8           = 0X77,
            VK_F9           = 0X78,
            VK_F10          = 0X79,
            VK_F11          = 0X7A,
            VK_F12          = 0X7B, //I only went up to F12, because honestly, who the hell has 24 F buttons?
            //and for the 8 people in the world who do, I think they can live without using them

            VK_NUMLOCK      = 0X90,
            VK_SCROLL       = 0X91, //Scroll-Lock
            VK_LSHIFT       = 0XA0,
            VK_RSHIFT       = 0XA1,
            VK_LCONTROL     = 0XA2,
            VK_RCONTROL     = 0XA3,
            //VK_LMENU        = 0XA4,
            //VK_RMENU        = 0XA5,
            //VK_PLAY         = 0XFA,
            //VK_ZOOM         = 0XFB 
        } //keycodes

        public delegate IntPtr HookDel(
            int nCode,
            IntPtr wParam,
            IntPtr lParam);

        public delegate void KeyHandler(
            IntPtr wParam,
            IntPtr lParam);

        private static IntPtr hhk = IntPtr.Zero;
        private static HookDel hd;
        private static KeyHandler kh;

        public static void CreateHook(KeyHandler _kh)
        {
            Process _this = Process.GetCurrentProcess();
            ProcessModule mod = _this.MainModule;
            hd = HookFunc;
            kh = _kh;

            hhk = API.SetWindowsHookEx(13, hd, API.GetModuleHandle(mod.ModuleName), 0);
			
			Console.WriteLine("CreateHook HAS RUN");
			
            //13 is the parameter specifying that we're gonna do a low-level keyboard hook

            //MessageBox.Show(Marshal.GetLastWin32Error().ToString()); //for debugging
            //Note that this could be a Console.WriteLine(), as well. I just happened
            //to be debugging this in a Windows Application
            //to get the errors, in VS 2005+ (possibly before) do Tools -> Error Lookup
        }

        public static bool DestroyHook()
        {
            //to be called when we're done with the hook

			Console.WriteLine("DestroyHook HAS RUN");
			
            return API.UnhookWindowsHookEx(hhk);
        }

        private static IntPtr HookFunc(
            int nCode,
            IntPtr wParam,
            IntPtr lParam)
        {
            int iwParam = wParam.ToInt32();
            if (nCode >= 0 &&
                (iwParam == 0x100 ||
                iwParam == 0x104)) //0x100 = WM_KEYDOWN, 0x104 = WM_SYSKEYDOWN
                 kh(wParam, lParam);

            return API.CallNextHookEx(hhk, nCode, wParam, lParam);
        }
    }
	
	public class TestKeybdHook
	{
	
		public static void KeyHandler(IntPtr wParam, IntPtr lParam)
		{
			  int key = Marshal.ReadInt32(lParam);
			  Hook.VK vk = (Hook.VK)key;
			  
			  Console.WriteLine("KeyHandler!");
			  
			   switch(vk)
			   {
					case Hook.VK.VK_F5: MessageBox.Show("You pressed F5!");
									  Console.WriteLine("You pressed F5!");
									  break;

					case Hook.VK.VK_F6: MessageBox.Show("You pressed F6!");
									  Console.WriteLine("You pressed F6!");
									  break;
					 //etc...
					 default: break;
			   }
		}
		
		static public void Main(string[] args)
		{
			Console.WriteLine("Hello from TestKeybdHook");
			
			// initialize hook
			// unfortunately it seems NOT to run in this example.. 
			Hook.CreateHook(KeyHandler); 
			
			
			// How do I trap ctrl-c in a C# console app - Stack Overflow - http://stackoverflow.com/questions/177856/how-do-i-trap-ctrl-c-in-a-c-console-app
			// Console.CancelKeyPress Event (System) - http://msdn.microsoft.com/en-us/library/system.console.cancelkeypress.aspx
			
			ConsoleKeyInfo cki;
			
			/*
			NOTE: without 
				Console.TreatControlCAsInput = false; 
			and 
				Console.CancelKeyPress += new ConsoleCancelEventHandler(myHandler); 
			CTRL+C simply exits the read! 
			*/
			
 			// Turn off the default system behavior when CTRL+C is pressed. When 
			// Console.TreatControlCAsInput is false, CTRL+C is treated as an
			// interrupt instead of as input.
			Console.TreatControlCAsInput = false;
			
			// Establish an event handler to process key press events.
			Console.CancelKeyPress += new ConsoleCancelEventHandler(myHandler);

			// start infinite loop here - will be broken by CTRL+C
			while (true)
			{
				// Prompt the user.
				Console.Write("Press any key, or 'X' to quit, or ");
				Console.WriteLine("CTRL+C to interrupt the read operation:");

				// Start a console read operation. Do not display the input.
				cki = Console.ReadKey(true); // this one is the blocking command

				//System.Threading.Thread.Sleep(1000); //1 second pause - instead of block; but only this (without a break) has a hard time reacting to Ctrl+C, and is likely to crash the PC

				// Announce the name of the key that was pressed .
				Console.WriteLine("  Key pressed: {0}\n", cki.Key);

				// Exit if the user pressed the 'X' key.
				if (cki.Key == ConsoleKey.X) break;
			}
			
			// destroy hook 
			Hook.DestroyHook(); 
			
		}
		
		/*
		   When you press CTRL+C, the read operation is interrupted and the 
		   console cancel event handler, myHandler, is invoked. Upon entry 
		   to the event handler, the Cancel property is false, which means 
		   the current process will terminate when the event handler terminates. 
		   However, the event handler sets the Cancel property to true, which 
		   means the process will not terminate and the read operation will resume.
		*/
		protected static void myHandler(object sender, ConsoleCancelEventArgs args)
		{
			// Announce that the event handler has been invoked.
			Console.WriteLine("\nThe read operation has been interrupted.");

			// Announce which key combination was pressed.
			Console.WriteLine("  Key pressed: {0}", args.SpecialKey);

			// Announce the initial value of the Cancel property.
			Console.WriteLine("  Cancel property: {0}", args.Cancel);

			// Set the Cancel property to true to prevent the process from terminating.
			Console.WriteLine("Setting the Cancel property to true...");
			args.Cancel = true;

			// Announce the new value of the Cancel property.
			Console.WriteLine("  Cancel property: {0}", args.Cancel);
			Console.WriteLine("The read operation will resume...\n");
		}
		
	}	
	
} 


