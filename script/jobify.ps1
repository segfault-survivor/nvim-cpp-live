# https://stackoverflow.com/questions/18983058/kill-child-processes-when-parent-powershell-process-is-killed

$CreateJobObjectSignature = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Jobify
{
  public enum JOBOBJECTINFOCLASS
  {
    AssociateCompletionPortInformation = 7,
    BasicLimitInformation = 2,
    BasicUIRestrictions = 4,
    EndOfJobTimeInformation = 6,
    ExtendedLimitInformation = 9,
    SecurityLimitInformation = 5,
    GroupInformation = 11
  }

  [StructLayout(LayoutKind.Sequential)]
  struct JOBOBJECT_BASIC_LIMIT_INFORMATION
  {
    public Int64 PerProcessUserTimeLimit;
    public Int64 PerJobUserTimeLimit;
    public UInt32 LimitFlags;
    public UIntPtr MinimumWorkingSetSize;
    public UIntPtr MaximumWorkingSetSize;
    public UInt32 ActiveProcessLimit;
    public Int64 Affinity;
    public UInt32 PriorityClass;
    public UInt32 SchedulingClass;
  }


  [StructLayout(LayoutKind.Sequential)]
  struct IO_COUNTERS
  {
    public UInt64 ReadOperationCount;
    public UInt64 WriteOperationCount;
    public UInt64 OtherOperationCount;
    public UInt64 ReadTransferCount;
    public UInt64 WriteTransferCount;
    public UInt64 OtherTransferCount;
  }

  [StructLayout(LayoutKind.Sequential)]
  struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
  {
    public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
    public IO_COUNTERS IoInfo;
    public UIntPtr ProcessMemoryLimit;
    public UIntPtr JobMemoryLimit;
    public UIntPtr PeakProcessMemoryUsed;
    public UIntPtr PeakJobMemoryUsed;
  }

  [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
  public static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string lpName);

  [DllImport("kernel32.dll")]
  public static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);

  [DllImport("kernel32.dll")]
  public static extern bool SetInformationJobObject(IntPtr hJob, JOBOBJECTINFOCLASS JobObjectInfoClass, IntPtr lpJobObjectInfo, uint cbJobObjectInfoLength);

  [DllImport("kernel32.dll")]
  public static extern IntPtr GetCurrentProcess();


  private const UInt32 JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000;
  public Jobify()
  {
    IntPtr hJob = CreateJobObject(IntPtr.Zero, null);

    JOBOBJECT_BASIC_LIMIT_INFORMATION info = new JOBOBJECT_BASIC_LIMIT_INFORMATION();
    info.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

    JOBOBJECT_EXTENDED_LIMIT_INFORMATION extendedInfo = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
    extendedInfo.BasicLimitInformation = info;

    int length = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
    IntPtr extendedInfoPtr = Marshal.AllocHGlobal(length);
    Marshal.StructureToPtr(extendedInfo, extendedInfoPtr, false);

    SetInformationJobObject(hJob, JOBOBJECTINFOCLASS.ExtendedLimitInformation, extendedInfoPtr, (uint)length);

    IntPtr hProcess = GetCurrentProcess();
    bool blRc = AssignProcessToJobObject(hJob, hProcess);

    Marshal.FreeHGlobal(extendedInfoPtr);
  }
}
"@

Add-Type -TypeDefinition $CreateJobObjectSignature 
$a = New-Object Jobify

& $args[0] $args[1..$args.Length]
$lec = $LASTEXITCODE
# Write-Host $lec
exit $lec
# Read-Host "!"
