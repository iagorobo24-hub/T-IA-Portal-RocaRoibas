using System;
using Siemens.Collaboration.Net;
using Siemens.Engineering;

/// <summary>
/// Independent, read-only proof that a standalone .NET Framework application can load
/// Siemens.Engineering V20 and enumerate TIA Portal processes without attaching or opening a project.
/// </summary>
internal static class Program
{
    public static int Main()
    {
        try
        {
            Api.Global.Openness().Initialize(tiaMajorVersion: 20);
            Console.WriteLine("resolverInitialized=true");
            Console.WriteLine("userInOpennessGroup=" + Api.Global.Openness().IsUserInGroup());
            Console.WriteLine("engineeringAssembly=" + typeof(TiaPortal).Assembly.FullName);
            Console.WriteLine("engineeringLocation=" + typeof(TiaPortal).Assembly.Location);
            Console.WriteLine("engineeringVersion=" + typeof(TiaPortal).Assembly.GetName().Version);
            Console.WriteLine("headlessCreationAttempted=false");
            Console.WriteLine("attachmentAttempted=false");

            foreach (TiaPortalProcess process in TiaPortal.GetProcesses())
            {
                var projectPath = process.ProjectPath == null ? string.Empty : process.ProjectPath.FullName;
                Console.WriteLine("process id=" + process.Id + " mode=" + process.Mode + " projectPath=" + projectPath);
            }

            Console.WriteLine("readOnlyApiProbe=true");
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex.GetType().FullName + ": " + ex.Message);
            if (ex.InnerException != null)
            {
                Console.Error.WriteLine("inner=" + ex.InnerException.GetType().FullName + ": " + ex.InnerException.Message);
            }

            return 1;
        }
    }
}
