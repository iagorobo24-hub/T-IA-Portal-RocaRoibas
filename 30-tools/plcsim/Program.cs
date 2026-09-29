using System.Runtime.InteropServices;
using System.Text.Json;
using System.Globalization;
using System.Text.RegularExpressions;

internal static class Program
{
    private const string ApiDllName = "Siemens.Simatic.Simulation.Runtime.Api.x64.dll";
    private const string ApiHeaderName = "SimulationRuntimeApi.h";

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate int InitializeDelegate(out IntPtr runtimeManager, uint interfaceVersion);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate int DestroyInterfaceDelegate(IntPtr runtimeInterface);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint ManagerCountDelegate(IntPtr runtimeManager);

    private static int Main(string[] args)
    {
        var apiDll = ResolveDefaultApiDll();
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

    private static string ResolveDefaultApiDll()
    {
        var commonFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.CommonProgramFilesX86);
        var apiRoot = Path.Combine(commonFilesX86, "Siemens", "PLCSIMADV", "API");
        if (Directory.Exists(apiRoot))
        {
            var candidates = Directory.GetDirectories(apiRoot)
                .Select(path => new { Path = path, Name = Path.GetFileName(path) })
                .Where(item => Version.TryParse(item.Name, out _))
                .OrderByDescending(item => Version.Parse(item.Name));
            foreach (var candidate in candidates)
            {
                var dll = Path.Combine(candidate.Path, ApiDllName);
                var header = Path.Combine(candidate.Path, ApiHeaderName);
                if (File.Exists(dll) && File.Exists(header)) return dll;
            }
        }

        return Path.Combine(apiRoot, "7.0", ApiDllName);
    }

    private static uint ReadInterfaceVersion(string apiDll)
    {
        var headerPath = Path.Combine(Path.GetDirectoryName(apiDll) ?? string.Empty, ApiHeaderName);
        if (!File.Exists(headerPath)) throw new FileNotFoundException("The Siemens API header beside the selected DLL is missing.", headerPath);

        var header = File.ReadAllText(headerPath);
        var match = Regex.Match(header, @"(?m)^\s*#define\s+DAPI_DLL_INTERFACE_VERSION\s+0x([0-9A-Fa-f]{8})\b");
        if (!match.Success) throw new InvalidDataException("The Siemens API header does not declare DAPI_DLL_INTERFACE_VERSION.");
        return uint.Parse(match.Groups[1].Value, NumberStyles.HexNumber, CultureInfo.InvariantCulture);
    }

    private static ProbeResult Probe(string apiDll, bool readManagerCount)
    {
        if (!File.Exists(apiDll))
        {
            return new(false, "missing", apiDll, null, null, null, "API DLL not found.", null);
        }

        IntPtr library = IntPtr.Zero;
        IntPtr manager = IntPtr.Zero;
        try
        {
            var interfaceVersion = ReadInterfaceVersion(apiDll);
            library = NativeLibrary.Load(apiDll);
            var initializeAddress = NativeLibrary.GetExport(library, "RuntimeApiEntry_Initialize");
            var destroyAddress = NativeLibrary.GetExport(library, "RuntimeApiEntry_DestroyInterface");
            var initialize = Marshal.GetDelegateForFunctionPointer<InitializeDelegate>(initializeAddress);
            var destroy = Marshal.GetDelegateForFunctionPointer<DestroyInterfaceDelegate>(destroyAddress);
            var initializeCode = initialize(out manager, interfaceVersion);
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
                $"0x{interfaceVersion:X8}",
                $"0x{initializeCode:X8}",
                cleanupCode.HasValue ? $"0x{cleanupCode.Value:X8}" : null,
                success ? "PLCSIM Advanced runtime API initialized and released." : "Runtime API initialization failed.",
                managerCount);
        }
        catch (Exception ex)
        {
            return new(false, "probe-failed", apiDll, null, null, null, ex.GetType().Name + ": " + ex.Message, null);
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
        $"PLCSIM API: {result.Status}\nDLL: {result.ApiDll}\nInterface: {result.InterfaceVersion ?? "-"}\nInitialize: {result.InitializeCode ?? "-"}\nDestroy: {result.DestroyCode ?? "-"}\nManager instances: {result.ManagerInstanceCount?.ToString() ?? "-"}\n{result.Message}";

    private sealed record ProbeResult(
        bool Success,
        string Status,
        string ApiDll,
        string? InterfaceVersion,
        string? InitializeCode,
        string? DestroyCode,
        string Message,
        uint? ManagerInstanceCount);
}
