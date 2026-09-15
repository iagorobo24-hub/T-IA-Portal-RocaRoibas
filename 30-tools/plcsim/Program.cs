using System.Runtime.InteropServices;
using System.Text.Json;

internal static class Program
{
    private const uint ApiInterfaceVersion = 0x00060000;
    private const string DefaultApiDll = @"C:\Program Files (x86)\Common Files\Siemens\PLCSIMADV\API\6.0\Siemens.Simatic.Simulation.Runtime.Api.x64.dll";

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate int InitializeDelegate(out IntPtr runtimeManager, uint interfaceVersion);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate int DestroyInterfaceDelegate(IntPtr runtimeInterface);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint ManagerCountDelegate(IntPtr runtimeManager);

    private static int Main(string[] args)
    {
        var apiDll = DefaultApiDll;
        var json = args.Any(a => string.Equals(a, "--json", StringComparison.OrdinalIgnoreCase));
        for (var i = 0; i < args.Length - 1; i++)
        {
            if (string.Equals(args[i], "--api-dll", StringComparison.OrdinalIgnoreCase))
            {
                apiDll = Path.GetFullPath(args[i + 1]);
            }
        }

        var result = Probe(apiDll, args.Any(a => string.Equals(a, "--manager-count", StringComparison.OrdinalIgnoreCase)));
        var output = JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true });
        Console.WriteLine(json ? output : FormatText(result));
        return result.Success ? 0 : 1;
    }

    private static ProbeResult Probe(string apiDll, bool readManagerCount)
    {
        if (!File.Exists(apiDll))
        {
            return new(false, "missing", apiDll, null, null, "API DLL not found.", null);
        }

        IntPtr library = IntPtr.Zero;
        IntPtr manager = IntPtr.Zero;
        try
        {
            library = NativeLibrary.Load(apiDll);
            var initializeAddress = NativeLibrary.GetExport(library, "RuntimeApiEntry_Initialize");
            var destroyAddress = NativeLibrary.GetExport(library, "RuntimeApiEntry_DestroyInterface");
            var initialize = Marshal.GetDelegateForFunctionPointer<InitializeDelegate>(initializeAddress);
            var destroy = Marshal.GetDelegateForFunctionPointer<DestroyInterfaceDelegate>(destroyAddress);
            var initializeCode = initialize(out manager, ApiInterfaceVersion);
            var success = initializeCode == 0 && manager != IntPtr.Zero;
            uint? managerCount = null;
            if (success && readManagerCount)
            {
                // The Siemens header exposes the manager as a C++ virtual interface.
                // In this build MSVC exposes one destructor slot before the first
                // declared operation; slot 7 is GetRegisteredInstancesCount().
                var vtable = Marshal.ReadIntPtr(manager);
                var method = Marshal.ReadIntPtr(vtable, 7 * IntPtr.Size);
                managerCount = Marshal.GetDelegateForFunctionPointer<ManagerCountDelegate>(method)(manager);
            }
            var cleanupCode = (int?)null;
            if (manager != IntPtr.Zero)
            {
                cleanupCode = destroy(manager);
                manager = IntPtr.Zero;
            }
            return new(
                success,
                success ? "initialized" : "initialization-failed",
                apiDll,
                $"0x{initializeCode:X8}",
                cleanupCode.HasValue ? $"0x{cleanupCode.Value:X8}" : null,
                success ? "PLCSIM Advanced runtime API initialized and released." : "Runtime API initialization failed.",
                managerCount);
        }
        catch (Exception ex)
        {
            return new(false, "probe-failed", apiDll, null, null, ex.GetType().Name + ": " + ex.Message, null);
        }
        finally
        {
            if (manager != IntPtr.Zero)
            {
                try { Marshal.GetDelegateForFunctionPointer<DestroyInterfaceDelegate>(NativeLibrary.GetExport(library, "RuntimeApiEntry_DestroyInterface"))(manager); }
                catch { }
            }
            if (library != IntPtr.Zero)
            {
                NativeLibrary.Free(library);
            }
        }
    }

    private static string FormatText(ProbeResult result) =>
        $"PLCSIM API: {result.Status}\nDLL: {result.ApiDll}\nInitialize: {result.InitializeCode ?? "-"}\nDestroy: {result.DestroyCode ?? "-"}\nManager instances: {result.ManagerInstanceCount?.ToString() ?? "-"}\n{result.Message}";

    private sealed record ProbeResult(
        bool Success,
        string Status,
        string ApiDll,
        string? InitializeCode,
        string? DestroyCode,
        string Message,
        uint? ManagerInstanceCount);
}
