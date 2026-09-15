#include <windows.h>

#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "SimulationRuntimeApi.h"

namespace
{
void PrintJsonString(const std::wstring& value)
{
    std::wcout << L"\"";
    for (const wchar_t character : value)
    {
        if (character == L'\\' || character == L'\"')
        {
            std::wcout << L'\\';
        }
        std::wcout << character;
    }
    std::wcout << L"\"";
}

void PrintCode(const wchar_t* name, ERuntimeErrorCode code)
{
    std::wcout << L"\"" << name << L"\":\"0x" << std::hex << static_cast<int>(code) << std::dec << L"\"";
}

bool HasArgument(int argc, wchar_t* argv[], const std::wstring& name)
{
    for (int index = 1; index < argc; ++index)
    {
        if (std::wstring(argv[index]) == name)
        {
            return true;
        }
    }
    return false;
}

std::wstring ArgumentValue(int argc, wchar_t* argv[], const std::wstring& name, const std::wstring& fallback)
{
    for (int index = 1; index + 1 < argc; ++index)
    {
        if (std::wstring(argv[index]) == name)
        {
            return argv[index + 1];
        }
    }
    return fallback;
}

bool ParseIp(const std::wstring& text, UIP* output)
{
    if (output == nullptr)
    {
        return false;
    }

    std::wistringstream stream(text);
    std::wstring part;
    int octet = 0;
    while (std::getline(stream, part, L'.'))
    {
        if (octet >= 4 || part.empty())
        {
            return false;
        }
        try
        {
            const unsigned long value = std::stoul(part);
            if (value > 255)
            {
                return false;
            }
            output->IPs[octet] = static_cast<BYTE>(value);
        }
        catch (...)
        {
            return false;
        }
        ++octet;
    }
    return octet == 4;
}

bool ContainsInsensitive(const std::wstring& value, const std::wstring& needle)
{
    if (needle.empty())
    {
        return true;
    }
    std::wstring valueLower = value;
    std::wstring needleLower = needle;
    for (wchar_t& character : valueLower) { character = static_cast<wchar_t>(towlower(character)); }
    for (wchar_t& character : needleLower) { character = static_cast<wchar_t>(towlower(character)); }
    return valueLower.find(needleLower) != std::wstring::npos;
}

bool ParseArea(const std::wstring& text, EArea* output)
{
    if (output == nullptr)
    {
        return false;
    }
    if (ContainsInsensitive(text, L"input"))
    {
        *output = EArea::SRA_INPUT;
        return true;
    }
    if (ContainsInsensitive(text, L"output"))
    {
        *output = EArea::SRA_OUTPUT;
        return true;
    }
    if (ContainsInsensitive(text, L"marker") || text == L"m")
    {
        *output = EArea::SRA_MARKER;
        return true;
    }
    return false;
}

bool ParseUInt32(const std::wstring& text, UINT32* output)
{
    if (output == nullptr || text.empty())
    {
        return false;
    }
    try
    {
        const unsigned long value = std::stoul(text);
        if (value > UINT32_MAX)
        {
            return false;
        }
        *output = static_cast<UINT32>(value);
        return true;
    }
    catch (...)
    {
        return false;
    }
}

bool ParseBitValue(const std::wstring& text, bool* output)
{
    if (output == nullptr)
    {
        return false;
    }
    if (text == L"1" || ContainsInsensitive(text, L"true") || ContainsInsensitive(text, L"on"))
    {
        *output = true;
        return true;
    }
    if (text == L"0" || ContainsInsensitive(text, L"false") || ContainsInsensitive(text, L"off"))
    {
        *output = false;
        return true;
    }
    return false;
}

void PrintProtocolFailure(const std::wstring& operation, const std::wstring& reason)
{
    std::wcout << L"{\"status\":\"failed\",\"op\":";
    PrintJsonString(operation);
    std::wcout << L",\"reason\":";
    PrintJsonString(reason);
    std::wcout << L"}\n";
}

void PrintProtocolCode(const std::wstring& operation, ERuntimeErrorCode code)
{
    std::wcout << L"{\"status\":\"failed\",\"op\":";
    PrintJsonString(operation);
    std::wcout << L",";
    PrintCode(L"code", code);
    std::wcout << L"}\n";
}

std::wstring NormalizeTagToken(std::wstring tag)
{
    if (tag.size() >= 2 && tag.front() == L'"' && tag.back() == L'"')
    {
        tag = tag.substr(1, tag.size() - 2);
    }
    return tag;
}

void PrintTagProtocolFailure(const std::wstring& operation, const std::wstring& tag, ERuntimeErrorCode code)
{
    std::wcout << L"{\"status\":\"failed\",\"op\":";
    PrintJsonString(operation);
    std::wcout << L",\"tag\":";
    PrintJsonString(tag);
    std::wcout << L",";
    PrintCode(L"code", code);
    std::wcout << L"}\n";
}

bool HandleSymbolicTagCommand(IInstance* instance, const std::wstring& operation, std::wistringstream& stream)
{
    const bool boolTag = operation == L"read-bool-tag" || operation == L"write-bool-tag";
    const bool uint8Tag = operation == L"read-uint8-tag" || operation == L"write-uint8-tag";
    const bool floatTag = operation == L"read-float-tag" || operation == L"write-float-tag";
    if (!boolTag && !uint8Tag && !floatTag)
    {
        return false;
    }

    std::wstring tag;
    stream >> tag;
    tag = NormalizeTagToken(tag);
    if (tag.empty())
    {
        PrintProtocolFailure(operation, L"tag is required");
        return true;
    }
    std::vector<wchar_t> buffer(tag.begin(), tag.end());
    buffer.push_back(L'\0');

    if (operation == L"read-bool-tag")
    {
        bool value = false;
        const ERuntimeErrorCode code = instance->ReadBool(buffer.data(), &value);
        if (code != SREC_OK) { PrintTagProtocolFailure(operation, tag, code); return true; }
        std::wcout << L"{\"status\":\"ok\",\"op\":\"read-bool-tag\",\"tag\":";
        PrintJsonString(tag);
        std::wcout << L",\"value\":" << (value ? L"true" : L"false") << L"}\n";
        std::wcout.flush();
        return true;
    }
    if (operation == L"read-uint8-tag")
    {
        UINT8 value = 0;
        const ERuntimeErrorCode code = instance->ReadUInt8(buffer.data(), &value);
        if (code != SREC_OK) { PrintTagProtocolFailure(operation, tag, code); return true; }
        std::wcout << L"{\"status\":\"ok\",\"op\":\"read-uint8-tag\",\"tag\":";
        PrintJsonString(tag);
        std::wcout << L",\"value\":" << static_cast<unsigned int>(value) << L"}\n";
        std::wcout.flush();
        return true;
    }
    if (operation == L"read-float-tag")
    {
        float value = 0.0F;
        const ERuntimeErrorCode code = instance->ReadFloat(buffer.data(), &value);
        if (code != SREC_OK) { PrintTagProtocolFailure(operation, tag, code); return true; }
        std::wcout << L"{\"status\":\"ok\",\"op\":\"read-float-tag\",\"tag\":";
        PrintJsonString(tag);
        std::wcout << L",\"value\":" << value << L"}\n";
        std::wcout.flush();
        return true;
    }

    std::wstring valueText;
    stream >> valueText;
    if (operation == L"write-bool-tag")
    {
        bool value = false;
        if (!ParseBitValue(valueText, &value)) { PrintProtocolFailure(operation, L"value must be 0, 1, false, true, off or on"); return true; }
        const ERuntimeErrorCode code = instance->WriteBool(buffer.data(), value);
        if (code != SREC_OK) { PrintTagProtocolFailure(operation, tag, code); return true; }
        std::wcout << L"{\"status\":\"ok\",\"op\":\"write-bool-tag\",\"tag\":";
        PrintJsonString(tag);
        std::wcout << L",\"value\":" << (value ? L"true" : L"false") << L"}\n";
        std::wcout.flush();
        return true;
    }
    if (operation == L"write-uint8-tag")
    {
        UINT32 parsed = 0;
        if (!ParseUInt32(valueText, &parsed) || parsed > 255) { PrintProtocolFailure(operation, L"value must be an integer from 0 to 255"); return true; }
        const ERuntimeErrorCode code = instance->WriteUInt8(buffer.data(), static_cast<UINT8>(parsed));
        if (code != SREC_OK) { PrintTagProtocolFailure(operation, tag, code); return true; }
        std::wcout << L"{\"status\":\"ok\",\"op\":\"write-uint8-tag\",\"tag\":";
        PrintJsonString(tag);
        std::wcout << L",\"value\":" << parsed << L"}\n";
        std::wcout.flush();
        return true;
    }

    try
    {
        const float value = std::stof(valueText);
        const ERuntimeErrorCode code = instance->WriteFloat(buffer.data(), value);
        if (code != SREC_OK) { PrintTagProtocolFailure(operation, tag, code); return true; }
        std::wcout << L"{\"status\":\"ok\",\"op\":\"write-float-tag\",\"tag\":";
        PrintJsonString(tag);
        std::wcout << L",\"value\":" << value << L"}\n";
    }
    catch (...)
    {
        PrintProtocolFailure(operation, L"value must be a floating-point number");
    }
    std::wcout.flush();
    return true;
}

bool HandleAcceptanceCommand(IInstance* instance, const std::wstring& command)
{
    if (instance == nullptr)
    {
        PrintProtocolFailure(L"command", L"instance is null");
        return true;
    }

    std::wistringstream stream(command);
    std::wstring operation;
    stream >> operation;
    if (operation.empty())
    {
        return true;
    }

    if (HandleSymbolicTagCommand(instance, operation, stream))
    {
        return true;
    }

    if (operation == L"read-area-size")
    {
        std::wstring areaText;
        stream >> areaText;
        EArea area{};
        if (!ParseArea(areaText, &area))
        {
            PrintProtocolFailure(operation, L"area must be input, output or marker");
            return true;
        }
        std::wcout << L"{\"status\":\"ok\",\"op\":\"read-area-size\",\"bytes\":"
                   << instance->GetAreaSize(area) << L"}\n";
        std::wcout.flush();
        return true;
    }

    const bool bitOperation = operation == L"read-bit" || operation == L"write-bit";
    const bool byteOperation = operation == L"read-byte" || operation == L"write-byte";
    if (!bitOperation && !byteOperation)
    {
        PrintProtocolFailure(operation, L"unknown command; expected read-bit, write-bit, read-byte, write-byte or read-area-size");
        return true;
    }

    std::wstring areaText;
    std::wstring offsetText;
    stream >> areaText >> offsetText;
    EArea area{};
    UINT32 offset = 0;
    if (!ParseArea(areaText, &area) || !ParseUInt32(offsetText, &offset))
    {
        PrintProtocolFailure(operation, L"expected area and unsigned byte offset");
        return true;
    }

    if (bitOperation)
    {
        std::wstring bitText;
        stream >> bitText;
        UINT32 bit = 0;
        if (!ParseUInt32(bitText, &bit) || bit > 7)
        {
            PrintProtocolFailure(operation, L"bit must be an integer from 0 to 7");
            return true;
        }
        if (operation == L"read-bit")
        {
            bool value = false;
            const ERuntimeErrorCode code = instance->ReadBit(area, offset, static_cast<UINT8>(bit), &value);
            if (code != SREC_OK)
            {
                PrintProtocolCode(operation, code);
                return true;
            }
            std::wcout << L"{\"status\":\"ok\",\"op\":\"read-bit\",\"value\":"
                       << (value ? L"true" : L"false") << L"}\n";
            std::wcout.flush();
            return true;
        }

        std::wstring valueText;
        stream >> valueText;
        bool value = false;
        if (!ParseBitValue(valueText, &value))
        {
            PrintProtocolFailure(operation, L"value must be 0, 1, false, true, off or on");
            return true;
        }
        const ERuntimeErrorCode code = instance->WriteBit(area, offset, static_cast<UINT8>(bit), value);
        if (code != SREC_OK)
        {
            PrintProtocolCode(operation, code);
            return true;
        }
        std::wcout << L"{\"status\":\"ok\",\"op\":\"write-bit\",\"value\":"
                   << (value ? L"true" : L"false") << L"}\n";
        std::wcout.flush();
        return true;
    }

    if (operation == L"read-byte")
    {
        BYTE value = 0;
        const ERuntimeErrorCode code = instance->ReadByte(area, offset, &value);
        if (code != SREC_OK)
        {
            PrintProtocolCode(operation, code);
            return true;
        }
        std::wcout << L"{\"status\":\"ok\",\"op\":\"read-byte\",\"value\":"
                   << static_cast<unsigned int>(value) << L"}\n";
        std::wcout.flush();
        return true;
    }

    std::wstring valueText;
    stream >> valueText;
    UINT32 parsedValue = 0;
    if (!ParseUInt32(valueText, &parsedValue) || parsedValue > 255)
    {
        PrintProtocolFailure(operation, L"byte value must be an integer from 0 to 255");
        return true;
    }
    const ERuntimeErrorCode code = instance->WriteByte(area, offset, static_cast<BYTE>(parsedValue));
    if (code != SREC_OK)
    {
        PrintProtocolCode(operation, code);
        return true;
    }
    std::wcout << L"{\"status\":\"ok\",\"op\":\"write-byte\",\"value\":"
               << parsedValue << L"}\n";
    std::wcout.flush();
    return true;
}

int RunDisposableProbe(ISimulationRuntimeManager* manager, int argc, wchar_t* argv[])
{
    const bool registerDisposable = HasArgument(argc, argv, L"--register-disposable");
    const bool registerInspect = HasArgument(argc, argv, L"--register-inspect");
    const bool powerOnDisposable = HasArgument(argc, argv, L"--power-on-disposable");
    const UINT32 registeredBefore = manager->GetRegisteredInstancesCount();
    std::wstring instanceName = L"TIAClaudeProbe_";
    instanceName += std::to_wstring(GetCurrentProcessId());
    IInstance* instance = nullptr;
    ERuntimeErrorCode registerCode = SREC_OK;
    ERuntimeErrorCode unregisterCode = SREC_OK;
    ERuntimeErrorCode destroyCode = SREC_OK;
    ERuntimeErrorCode powerOnCode = SREC_OK;
    ERuntimeErrorCode powerOffCode = SREC_OK;
    bool registered = false;
    bool unregistered = false;
    INT32 inspectedId = -1;
    std::wstring inspectedName;
    ERuntimeErrorCode inspectedNameCode = SREC_OK;
    ECPUType inspectedCpuType = SRCT_1500_Unspecified;
    ECommunicationInterface inspectedCommunicationInterface = SRCI_NONE;
    EOperatingState inspectedOperatingState = SROS_OFF;
    UINT32 inspectedControllerIpCount = 0;

    if (registerDisposable || registerInspect || powerOnDisposable)
    {
        registerCode = manager->RegisterInstance(SRCT_1516F, instanceName.data(), &instance);
        registered = registerCode == SREC_OK && instance != nullptr;
        if (registered)
        {
            const SInstanceInfo info = instance->GetInfo();
            WCHAR reportedName[DINSTANCE_NAME_MAX_LENGTH] = {};
            inspectedId = info.ID;
            inspectedNameCode = instance->GetName(reportedName, DINSTANCE_NAME_MAX_LENGTH);
            inspectedName = reportedName;
            inspectedCpuType = instance->GetCPUType();
            inspectedCommunicationInterface = instance->GetCommunicationInterface();
            inspectedOperatingState = instance->GetOperatingState();
            inspectedControllerIpCount = instance->GetControllerIPCount();
            if (powerOnDisposable)
            {
                powerOnCode = instance->PowerOn(60000);
                if (powerOnCode == SREC_OK)
                {
                    powerOffCode = instance->PowerOff(60000);
                }
            }
            unregisterCode = instance->UnregisterInstance();
            unregistered = unregisterCode == SREC_OK;
            destroyCode = DestroyInterface(instance);
            instance = nullptr;
        }
    }

    const UINT32 registeredAfter = manager->GetRegisteredInstancesCount();
    const bool success =
        (!(registerDisposable || registerInspect || powerOnDisposable) ||
         (registered && unregistered && destroyCode == SREC_OK && registeredAfter == registeredBefore &&
          (!powerOnDisposable || (powerOnCode == SREC_OK && powerOffCode == SREC_OK))));

    std::wcout << L"{\"status\":\"" << (success ? L"ready" : L"failed") << L"\",";
    std::wcout << L"\"registeredBefore\":" << registeredBefore << L",";
    std::wcout << L"\"registeredAfter\":" << registeredAfter << L",";
    std::wcout << L"\"registerDisposable\":" << (registerDisposable || registerInspect || powerOnDisposable ? L"true" : L"false") << L",";
    std::wcout << L"\"powerOnDisposable\":" << (powerOnDisposable ? L"true" : L"false") << L",";
    std::wcout << L"\"instanceName\":";
    PrintJsonString(instanceName);
    std::wcout << L",\"inspectedId\":" << inspectedId << L",";
    std::wcout << L"\"inspectedName\":";
    PrintJsonString(inspectedName);
    std::wcout << L",\"inspectedNameCode\":\"0x" << std::hex << static_cast<int>(inspectedNameCode) << std::dec << L"\"";
    std::wcout << L",\"inspectedCpuType\":" << static_cast<int>(inspectedCpuType) << L",";
    std::wcout << L"\"inspectedCommunicationInterface\":" << static_cast<int>(inspectedCommunicationInterface) << L",";
    std::wcout << L"\"inspectedOperatingState\":" << static_cast<int>(inspectedOperatingState) << L",";
    std::wcout << L"\"inspectedControllerIpCount\":" << inspectedControllerIpCount << L",";
    PrintCode(L"powerOnCode", powerOnCode);
    std::wcout << L",";
    PrintCode(L"powerOffCode", powerOffCode);
    std::wcout << L",";
    PrintCode(L"registerCode", registerCode);
    std::wcout << L",";
    PrintCode(L"unregisterCode", unregisterCode);
    std::wcout << L",";
    PrintCode(L"destroyCode", destroyCode);
    std::wcout << L"}\n";
    return success ? 0 : 1;
}

int RunAcceptanceInstance(ISimulationRuntimeManager* manager, int argc, wchar_t* argv[])
{
    const std::wstring instanceName = ArgumentValue(argc, argv, L"--name", L"TIAClaudeAcceptance_1516F");
    const std::wstring interfaceNeedle = ArgumentValue(argc, argv, L"--interface", L"Siemens PLCSIM Virtual Ethernet Adapter");
    const std::wstring ipText = ArgumentValue(argc, argv, L"--ip", L"192.168.0.1");
    const std::wstring maskText = ArgumentValue(argc, argv, L"--mask", L"255.255.255.0");
    const std::wstring gatewayText = ArgumentValue(argc, argv, L"--gateway", L"0.0.0.0");
    const UINT32 timeoutMs = static_cast<UINT32>(std::stoul(ArgumentValue(argc, argv, L"--timeout-ms", L"60000")));

    UINT interfaceCount = 0;
    const ERuntimeErrorCode countCode = manager->GetNetInterfaces(nullptr, &interfaceCount);
    // PLCSIM Advanced V6 reports SREC_INDEX_OUT_OF_RANGE for the count-only
    // call even though it has populated interfaceCount. The count is the
    // useful result here; the second call is the authoritative enumeration.
    if (interfaceCount == 0)
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"enumerate-interfaces\",";
        PrintCode(L"code", countCode);
        std::wcout << L",\"interfaceCount\":" << interfaceCount << L"}\n";
        return 1;
    }

    std::vector<SNetInterfaceInfo> interfaces(interfaceCount);
    const ERuntimeErrorCode listCode = manager->GetNetInterfaces(interfaces.data(), &interfaceCount);
    const SNetInterfaceInfo* selected = nullptr;
    for (const SNetInterfaceInfo& candidate : interfaces)
    {
        if (ContainsInsensitive(candidate.interfaceDescription, interfaceNeedle) ||
            ContainsInsensitive(candidate.interfaceName, interfaceNeedle))
        {
            selected = &candidate;
            break;
        }
    }
    if (listCode != SREC_OK || selected == nullptr)
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"select-interface\",";
        PrintCode(L"code", listCode);
        std::wcout << L",\"requested\":";
        PrintJsonString(interfaceNeedle);
        std::wcout << L",\"interfaceCount\":" << interfaceCount << L",\"interfaces\":[";
        for (UINT index = 0; index < interfaceCount; ++index)
        {
            if (index > 0) { std::wcout << L","; }
            std::wcout << L"{\"name\":";
            PrintJsonString(interfaces[index].interfaceName);
            std::wcout << L",\"description\":";
            PrintJsonString(interfaces[index].interfaceDescription);
            std::wcout << L",\"index\":" << interfaces[index].interfaceIndex << L"}";
        }
        std::wcout << L"]}\n";
        return 1;
    }

    UIP ip{};
    UIP mask{};
    UIP gateway{};
    if (!ParseIp(ipText, &ip) || !ParseIp(maskText, &mask) || !ParseIp(gatewayText, &gateway))
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"parse-ip\"}\n";
        return 1;
    }

    IInstance* instance = nullptr;
    const ERuntimeErrorCode registerCode = manager->RegisterInstance(SRCT_1516F, const_cast<wchar_t*>(instanceName.c_str()), &instance);
    if (registerCode != SREC_OK || instance == nullptr)
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"register-instance\",";
        PrintCode(L"code", registerCode);
        std::wcout << L"}\n";
        return 1;
    }

    const ERuntimeErrorCode mappingCode = instance->SetNetInterfaceMapping(EPLCInterface::IE1, selected->interfaceName);
    SIPSuite4 suite{};
    suite.IPAddress = ip;
    suite.SubnetMask = mask;
    suite.DefaultGateway = gateway;
    const ERuntimeErrorCode ipCode = instance->SetIPSuite(0, suite, true);
    const ERuntimeErrorCode bindingCode = manager->SetNetInterfaceBindings(selected->interfaceIndex);
    const ERuntimeErrorCode powerOnCode =
        mappingCode == SREC_OK && ipCode == SREC_OK && bindingCode == SREC_OK
            ? instance->PowerOn(timeoutMs)
            : SREC_OK;
    const bool ready = mappingCode == SREC_OK && ipCode == SREC_OK && bindingCode == SREC_OK && powerOnCode == SREC_OK;

    std::wcout << L"{\"status\":\"" << (ready ? L"ready" : L"failed") << L"\",";
    std::wcout << L"\"stage\":\"" << (ready ? L"running" : L"configure") << L"\",";
    std::wcout << L"\"instanceName\":";
    PrintJsonString(instanceName);
    std::wcout << L",\"interfaceName\":";
    PrintJsonString(selected->interfaceName);
    std::wcout << L",\"interfaceDescription\":";
    PrintJsonString(selected->interfaceDescription);
    std::wcout << L",\"interfaceIndex\":" << selected->interfaceIndex << L",";
    std::wcout << L"\"ip\":";
    PrintJsonString(ipText);
    std::wcout << L",";
    PrintCode(L"mappingCode", mappingCode);
    std::wcout << L",";
    PrintCode(L"ipCode", ipCode);
    std::wcout << L",";
    PrintCode(L"bindingCode", bindingCode);
    std::wcout << L",";
    PrintCode(L"powerOnCode", powerOnCode);
    std::wcout << L"}\n";
    std::wcout.flush();

    if (!ready)
    {
        instance->UnregisterInstance();
        DestroyInterface(instance);
        return 1;
    }

    // Keep the registered CPU alive while TIA downloads to it. Send "stop" on
    // stdin after the behavioral acceptance has finished.
    std::wstring command;
    while (std::getline(std::wcin, command))
    {
        if (command == L"stop" || command == L"quit")
        {
            break;
        }
        HandleAcceptanceCommand(instance, command);
    }

    const ERuntimeErrorCode powerOffCode = instance->PowerOff(timeoutMs);
    const ERuntimeErrorCode unregisterCode = instance->UnregisterInstance();
    const ERuntimeErrorCode destroyCode = DestroyInterface(instance);
    const bool stopped = powerOffCode == SREC_OK && unregisterCode == SREC_OK && destroyCode == SREC_OK;
    std::wcout << L"{\"status\":\"" << (stopped ? L"stopped" : L"cleanup-failed") << L"\",";
    PrintCode(L"powerOffCode", powerOffCode);
    std::wcout << L",";
    PrintCode(L"unregisterCode", unregisterCode);
    std::wcout << L",";
    PrintCode(L"destroyCode", destroyCode);
    std::wcout << L"}\n";
    return stopped ? 0 : 1;
}
}

int wmain(int argc, wchar_t* argv[])
{
    const bool acceptance = HasArgument(argc, argv, L"--register-acceptance");
    ISimulationRuntimeManager* manager = nullptr;
    const ERuntimeErrorCode initializeCode = InitializeApi(&manager);
    if (initializeCode != SREC_OK || manager == nullptr)
    {
        std::wcout << L"{\"status\":\"initialization-failed\",";
        PrintCode(L"initializeCode", initializeCode);
        std::wcout << L"}\n";
        return 1;
    }

    const int exitCode = acceptance
        ? RunAcceptanceInstance(manager, argc, argv)
        : RunDisposableProbe(manager, argc, argv);
    const ERuntimeErrorCode shutdownCode = ShutdownAndFreeApi(manager);
    if (exitCode != 0 || shutdownCode != SREC_OK)
    {
        std::wcerr << L"PLCSIM runtime shutdown code: 0x" << std::hex << static_cast<int>(shutdownCode) << std::dec << L"\n";
        return 1;
    }
    return 0;
}
