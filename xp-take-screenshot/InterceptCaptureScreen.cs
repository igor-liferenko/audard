//How can I save a screenshot directly to a file in Windows? - Stack Overflow - 
//http://stackoverflow.com/questions/158151/how-can-i-save-a-screenshot-directly-to-a-file-in-windows
//Stephen Toub : Low-Level Keyboard Hook in C# - 
//http://blogs.msdn.com/toub/archive/2006/05/03/589423.aspx

using System;
using System.Drawing;
using System.IO;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Globalization; //CultureInfo
// from keyboard hook: 
using System.Diagnostics;
using System.Windows.Forms; // for Application and Keys

public class IntercaptCaptureScreen
{

	// from keyboard hook: 
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private static LowLevelKeyboardProc _proc = HookCallback;
    private static IntPtr _hookID = IntPtr.Zero;
	
	static public void Main(string[] args)
	{
		//CaptureScreenshot(); // test
		Console.WriteLine("IntercaptCaptureScreen starting - use INSERT to grab screenshot...");
		Console.WriteLine("... press CTRL+C to exit...");
        _hookID = SetHook(_proc);
        Application.Run();
        UnhookWindowsHookEx(_hookID);		
	}

	/* KEYBOARD HOOK RELATED */
    private static IntPtr SetHook(LowLevelKeyboardProc proc)
    {
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule)
        {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc,
                GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private delegate IntPtr LowLevelKeyboardProc(
        int nCode, IntPtr wParam, IntPtr lParam);

    private static IntPtr HookCallback(
        int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN)
        {
            int vkCode = Marshal.ReadInt32(lParam);
            //Console.WriteLine((Keys)vkCode);
			// well no need to output usual chars here - uncomment below line to debug
            //Console.WriteLine("It is: " + (Keys)vkCode + " - " + vkCode);
			
			// REACT ON INSERT KEY HERE - Insert - 45
			if (vkCode == 45)
			{
				Console.WriteLine("GOT INSERT!!!");
				CaptureScreenshot(); 
			}
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook,
        LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode,
        IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
	
	/* END KEYBOARD HOOK RELATED */
	
	public static void CaptureScreenshot()
	{
		try
		{
			Bitmap capture = IntercaptCaptureScreen.GetDesktopImage();
			DateTime timestamp = DateTime.Now;
			String tsstr = timestamp.ToString("yyyy-MM-dd-ddd-HH-mm-ss", CultureInfo.CreateSpecificCulture("en-US"));
			String tfname = tsstr + "-screen.png";
			Console.WriteLine(tfname);

			string file = Path.Combine(Environment.CurrentDirectory, tfname);
			ImageFormat format = ImageFormat.Png; // note, Png is case sensitive - no 'png' or 'PNG' !
			capture.Save(file, format);
		}
		catch (Exception e)
		{
			Console.WriteLine(e);
		}	
	}
	
	public static Bitmap GetDesktopImage()
	{
		WIN32_API.SIZE size;

		IntPtr 	hDC = WIN32_API.GetDC(WIN32_API.GetDesktopWindow()); 
		IntPtr hMemDC = WIN32_API.CreateCompatibleDC(hDC);

		size.cx = WIN32_API.GetSystemMetrics(WIN32_API.SM_CXSCREEN);
		size.cy = WIN32_API.GetSystemMetrics(WIN32_API.SM_CYSCREEN);

		m_HBitmap = WIN32_API.CreateCompatibleBitmap(hDC, size.cx, size.cy);

		if (m_HBitmap!=IntPtr.Zero)
		{
			IntPtr hOld = (IntPtr) WIN32_API.SelectObject(hMemDC, m_HBitmap);
			WIN32_API.BitBlt(hMemDC, 0, 0,size.cx,size.cy, hDC, 0, 0, WIN32_API.SRCCOPY);
			WIN32_API.SelectObject(hMemDC, hOld);
			WIN32_API.DeleteDC(hMemDC);
			WIN32_API.ReleaseDC(WIN32_API.GetDesktopWindow(), hDC);
			return System.Drawing.Image.FromHbitmap(m_HBitmap); 
		}
		return null;
	}

	protected static IntPtr m_HBitmap;
}

public class WIN32_API
{
	public struct SIZE
	{
		public int cx;
		public int cy;
	}
	public  const int SRCCOPY = 13369376;
	public  const int SM_CXSCREEN=0;
	public  const int SM_CYSCREEN=1;

	[DllImport("gdi32.dll",EntryPoint="DeleteDC")]
	public static extern IntPtr DeleteDC(IntPtr hDc);

	[DllImport("gdi32.dll",EntryPoint="DeleteObject")]
	public static extern IntPtr DeleteObject(IntPtr hDc);

	[DllImport("gdi32.dll",EntryPoint="BitBlt")]
	public static extern bool BitBlt(IntPtr hdcDest,int xDest,int yDest,int wDest,int hDest,IntPtr hdcSource,int xSrc,int ySrc,int RasterOp);

	[DllImport ("gdi32.dll",EntryPoint="CreateCompatibleBitmap")]
	public static extern IntPtr CreateCompatibleBitmap(IntPtr hdc,	int nWidth, int nHeight);

	[DllImport ("gdi32.dll",EntryPoint="CreateCompatibleDC")]
	public static extern IntPtr CreateCompatibleDC(IntPtr hdc);

	[DllImport ("gdi32.dll",EntryPoint="SelectObject")]
	public static extern IntPtr SelectObject(IntPtr hdc,IntPtr bmp);

	[DllImport("user32.dll", EntryPoint="GetDesktopWindow")]
	public static extern IntPtr GetDesktopWindow();

	[DllImport("user32.dll",EntryPoint="GetDC")]
	public static extern IntPtr GetDC(IntPtr ptr);

	[DllImport("user32.dll",EntryPoint="GetSystemMetrics")]
	public static extern int GetSystemMetrics(int abc);

	[DllImport("user32.dll",EntryPoint="GetWindowDC")]
	public static extern IntPtr GetWindowDC(Int32 ptr);

	[DllImport("user32.dll",EntryPoint="ReleaseDC")]
	public static extern IntPtr ReleaseDC(IntPtr hWnd,IntPtr hDc);
}
