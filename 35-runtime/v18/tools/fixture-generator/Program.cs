using System;
using System.IO;
using System.Linq;
using Siemens.Collaboration.Net;
using Siemens.Engineering;
using Siemens.Engineering.HW;
using Siemens.Engineering.HW.Features;
using Siemens.Engineering.Compiler;
using Siemens.Engineering.SW;

/// <summary>
/// Crea un proyecto TIA Portal V18 DESECHABLE para usarlo como fixture de pruebas de solo lectura.
///
/// Nunca toca un proyecto de cliente ni un original de 50-examples/: crea uno nuevo y vacio en el
/// directorio que se le pase. Abre TIA Portal sin interfaz (WithoutUserInterface) y lo cierra al
/// terminar. No descarga nada a ningun PLC, real o simulado.
///
/// Uso:  TiaClaude.V18Fixture.exe &lt;directorio-destino&gt; [nombre-proyecto]
/// </summary>
internal static class Program
{
    // Candidatos de CPU en orden de preferencia. El catalogo varia entre instalaciones y niveles
    // de update, asi que se prueban varios y se usa el primero que el catalogo de V18 acepte.
    private static readonly string[] CpuCandidates =
    {
        "OrderNumber:6ES7 511-1AK02-0AB0/V2.9",
        "OrderNumber:6ES7 511-1AK02-0AB0/V2.8",
        "OrderNumber:6ES7 511-1AK02-0AB0/V2.6",
        "OrderNumber:6ES7 513-1AL02-0AB0/V2.9",
        "OrderNumber:6ES7 515-2AM02-0AB0/V2.9",
        "OrderNumber:6ES7 214-1AG40-0XB0/V4.5",
        "OrderNumber:6ES7 214-1AG40-0XB0/V4.4"
    };

    public static int Main(string[] args)
    {
        if (args.Length < 1)
        {
            Console.Error.WriteLine("Uso: TiaClaude.V18Fixture.exe <directorio-destino> [nombre-proyecto]");
            return 2;
        }

        var targetDir = Path.GetFullPath(args[0]);
        var projectName = args.Length > 1 ? args[1] : "TiaClaudeFixture_V18";

        TiaPortal portal = null;
        try
        {
            Api.Global.Openness().Initialize(tiaMajorVersion: 18);
            Console.WriteLine("resolverInitialized=true");
            Console.WriteLine("userInOpennessGroup=" + Api.Global.Openness().IsUserInGroup());
            Console.WriteLine("engineeringVersion=" + typeof(TiaPortal).Assembly.GetName().Version);
            Console.WriteLine("engineeringLocation=" + typeof(TiaPortal).Assembly.Location);

            Directory.CreateDirectory(targetDir);

            Console.WriteLine("openingPortal=WithoutUserInterface");
            portal = new TiaPortal(TiaPortalMode.WithoutUserInterface);
            Console.WriteLine("portalOpened=true");

            var project = portal.Projects.Create(new DirectoryInfo(targetDir), projectName);
            Console.WriteLine("projectCreated=" + project.Path.FullName);

            Device device = null;
            foreach (var mlfb in CpuCandidates)
            {
                try
                {
                    device = project.Devices.CreateWithItem(mlfb, "PLC_1", "PLC_1");
                    Console.WriteLine("cpuCreated=" + mlfb);
                    break;
                }
                catch (Exception ex)
                {
                    Console.WriteLine("cpuRejected=" + mlfb + " reason=" + ex.Message.Split('\n')[0].Trim());
                }
            }

            if (device == null)
            {
                Console.Error.WriteLine("Ningun MLFB del catalogo probado pudo instanciarse en V18.");
                project.Close();
                return 1;
            }

            var software = FindPlcSoftware(device);
            if (software == null)
            {
                Console.Error.WriteLine("PlcSoftware no localizado; el fixture no sirve para el smoke test.");
                project.Close();
                return 1;
            }

            Console.WriteLine("plcSoftware=" + software.Name);

            // Un FB en SCL, generado desde una fuente externa. Sin el, el fixture solo tendria el
            // OB1 en LAD, que no tiene forma de fuente y no permite probar el export textual.
            AddSclFunctionBlock(software, targetDir);

            // Contenido adicional para que el inventario de lectura sea significativo: sin UDT,
            // tags, constantes ni watch table, herramientas como GetTypes o GetTags devuelven
            // vacio y no se puede distinguir "no soportado" de "fixture vacio".
            AddDataTypeAndDataBlock(software, targetDir);
            AddTagsAndConstants(software);
            AddWatchTable(software);

            // Compilar: un bloque recien creado es 'inconsistent' y TIA se niega a exportarlo.
            Console.WriteLine("compiling=true");
            var compileResult = software.GetService<ICompilable>().Compile();
            Console.WriteLine("compileState=" + compileResult.State);
            Console.WriteLine("compileErrors=" + compileResult.ErrorCount);
            Console.WriteLine("compileWarnings=" + compileResult.WarningCount);

            Console.WriteLine("blockCount=" + software.BlockGroup.Blocks.Count);
            Console.WriteLine("blocks=" + string.Join(",", software.BlockGroup.Blocks.Select(b => b.Name + ":" + b.ProgrammingLanguage)));

            project.Save();
            Console.WriteLine("projectSaved=true");
            Console.WriteLine("projectPath=" + project.Path.FullName);
            project.Close();
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex.GetType().FullName + ": " + ex.Message);
            for (var inner = ex.InnerException; inner != null; inner = inner.InnerException)
            {
                Console.Error.WriteLine("inner=" + inner.GetType().FullName + ": " + inner.Message);
            }
            return 1;
        }
        finally
        {
            if (portal != null)
            {
                portal.Dispose();
                Console.WriteLine("portalDisposed=true");
            }
        }
    }

    /// <summary>
    /// Escribe un .scl minimo y lo importa como fuente externa, generando el FB correspondiente.
    /// Es la via que soporta Openness desde V15.1: no existe una API para crear un bloque SCL
    /// directamente. El fichero .scl temporal se borra despues.
    /// </summary>
    private static void AddSclFunctionBlock(PlcSoftware software, string targetDir)
    {
        var sclPath = Path.Combine(targetDir, "FB_ScaleValue.scl");
        const string scl =
            "FUNCTION_BLOCK \"FB_ScaleValue\"\r\n" +
            "{ S7_Optimized_Access := 'TRUE' }\r\n" +
            "VERSION : 0.1\r\n" +
            "   VAR_INPUT\r\n" +
            "      rawValue : INT;\r\n" +
            "      rawMin : INT;\r\n" +
            "      rawMax : INT;\r\n" +
            "      engMin : REAL;\r\n" +
            "      engMax : REAL;\r\n" +
            "   END_VAR\r\n" +
            "   VAR_OUTPUT\r\n" +
            "      engValue : REAL;\r\n" +
            "      valid : BOOL;\r\n" +
            "   END_VAR\r\n" +
            "BEGIN\r\n" +
            "   // Escalado lineal de una entrada analogica a unidades de ingenieria.\r\n" +
            "   IF #rawMax > #rawMin THEN\r\n" +
            "      #engValue := #engMin + (INT_TO_REAL(#rawValue - #rawMin) * (#engMax - #engMin))\r\n" +
            "                   / INT_TO_REAL(#rawMax - #rawMin);\r\n" +
            "      #valid := TRUE;\r\n" +
            "   ELSE\r\n" +
            "      #engValue := 0.0;\r\n" +
            "      #valid := FALSE;\r\n" +
            "   END_IF;\r\n" +
            "END_FUNCTION_BLOCK\r\n";

        try
        {
            File.WriteAllText(sclPath, scl);
            var source = software.ExternalSourceGroup.ExternalSources.CreateFromFile("FB_ScaleValue", sclPath);
            Console.WriteLine("externalSourceCreated=" + source.Name);
            source.GenerateBlocksFromSource();
            Console.WriteLine("sclBlockGenerated=FB_ScaleValue");
        }
        catch (Exception ex)
        {
            Console.WriteLine("sclBlockFailed=" + ex.Message.Split('\n')[0].Trim());
        }
        finally
        {
            if (File.Exists(sclPath)) { File.Delete(sclPath); }
        }
    }

    /// <summary>
    /// Un UDT y un DB global, ambos desde fuente externa. Dan contenido a GetTypes, GetTypeInfo,
    /// GetTypeSource, GenerateTypeSource, ExportType y ExportTypes, que sobre un PLC recien creado
    /// devolverian listas vacias.
    /// </summary>
    private static void AddDataTypeAndDataBlock(PlcSoftware software, string targetDir)
    {
        const string udt =
            "TYPE \"UDT_MotorStatus\"\r\n" +
            "VERSION : 0.1\r\n" +
            "   STRUCT\r\n" +
            "      running : BOOL;\r\n" +
            "      faulted : BOOL;\r\n" +
            "      hours : DINT;\r\n" +
            "      lastCurrent : REAL;\r\n" +
            "   END_STRUCT;\r\n" +
            "END_TYPE\r\n";

        const string db =
            "DATA_BLOCK \"DB_PlantState\"\r\n" +
            "{ S7_Optimized_Access := 'TRUE' }\r\n" +
            "VERSION : 0.1\r\n" +
            "NON_RETAIN\r\n" +
            "   STRUCT\r\n" +
            "      cycleCount : DINT;\r\n" +
            "      lineSpeed : REAL;\r\n" +
            "      motor1 : \"UDT_MotorStatus\";\r\n" +
            "   END_STRUCT;\r\n" +
            "BEGIN\r\n" +
            "END_DATA_BLOCK\r\n";

        // El UDT primero: el DB lo referencia.
        ImportSource(software, targetDir, "UDT_MotorStatus", "UDT_MotorStatus.udt", udt);
        ImportSource(software, targetDir, "DB_PlantState", "DB_PlantState.db", db);
    }

    /// <summary>Escribe una fuente externa, la importa y genera sus objetos.</summary>
    private static void ImportSource(PlcSoftware software, string targetDir, string name, string fileName, string content)
    {
        var path = Path.Combine(targetDir, fileName);
        try
        {
            File.WriteAllText(path, content);
            var source = software.ExternalSourceGroup.ExternalSources.CreateFromFile(name, path);
            source.GenerateBlocksFromSource();
            Console.WriteLine("generated=" + name);
        }
        catch (Exception ex)
        {
            Console.WriteLine("generateFailed=" + name + " reason=" + ex.Message.Split('\n')[0].Trim());
        }
        finally
        {
            if (File.Exists(path)) { File.Delete(path); }
        }
    }

    /// <summary>
    /// Tags y constantes en la tabla estandar. Sin ellos GetTags, GetTagInfo, GetTagTableInfo,
    /// GetConstants y ExportTagTable no tienen nada que devolver.
    /// </summary>
    private static void AddTagsAndConstants(PlcSoftware software)
    {
        try
        {
            var table = software.TagTableGroup.TagTables.FirstOrDefault();
            if (table == null)
            {
                Console.WriteLine("tagTable=NOT-FOUND");
                return;
            }

            table.Tags.Create("MotorRunning", "Bool", "%I0.0");
            table.Tags.Create("MotorFault", "Bool", "%I0.1");
            table.Tags.Create("MotorStart", "Bool", "%Q0.0");
            table.Tags.Create("AnalogIn", "Int", "%IW64");
            // En V18 la propiedad es UserConstants, no Constants (SystemConstants es de solo lectura).
            table.UserConstants.Create("MAX_SPEED", "Real", "1500.0");
            table.UserConstants.Create("SCAN_MS", "Int", "100");
            Console.WriteLine("tagTable=" + table.Name + " tags=" + table.Tags.Count + " userConstants=" + table.UserConstants.Count);
        }
        catch (Exception ex)
        {
            Console.WriteLine("tagsFailed=" + ex.Message.Split('\n')[0].Trim());
        }
    }

    /// <summary>Una watch table con entradas, para GetWatchTables/GetWatchTableInfo/ExportWatchTable.</summary>
    private static void AddWatchTable(PlcSoftware software)
    {
        try
        {
            var watch = software.WatchAndForceTableGroup.WatchTables.Create("WT_Motor");
            // Limitacion observada en Openness V18: PlcWatchTable.Entries es un
            // PlcTableCommentEntryComposition cuyo unico Create() no acepta argumentos, asi que no
            // se pueden anadir entradas con tag/direccion desde la API. La via seria importar la
            // tabla desde XML. La tabla vacia basta para GetWatchTables y GetWatchTableInfo.
            Console.WriteLine("watchTable=" + watch.Name + " entries=" + watch.Entries.Count + " (vacia: ver comentario)");
        }
        catch (Exception ex)
        {
            Console.WriteLine("watchTableFailed=" + ex.Message.Split('\n')[0].Trim());
        }
    }

    /// <summary>Recorre los DeviceItems buscando el contenedor que expone un PlcSoftware.</summary>
    private static PlcSoftware FindPlcSoftware(Device device)
    {
        foreach (DeviceItem item in device.DeviceItems)
        {
            var found = FindPlcSoftware(item);
            if (found != null)
            {
                return found;
            }
        }

        return null;
    }

    private static PlcSoftware FindPlcSoftware(DeviceItem item)
    {
        var container = item.GetService<SoftwareContainer>();
        if (container?.Software is PlcSoftware plcSoftware)
        {
            return plcSoftware;
        }

        foreach (DeviceItem child in item.DeviceItems)
        {
            var found = FindPlcSoftware(child);
            if (found != null)
            {
                return found;
            }
        }

        return null;
    }
}
