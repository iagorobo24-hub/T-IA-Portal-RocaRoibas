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

void PrintIpv4(const UIP& address)
{
    std::wcout << L"\""
               << static_cast<unsigned int>(address.IPs[3]) << L"."
               << static_cast<unsigned int>(address.IPs[2]) << L"."
               << static_cast<unsigned int>(address.IPs[1]) << L"."
               << static_cast<unsigned int>(address.IPs[0]) << L"\"";
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
            // The runtime stores the octets in reverse order: IPs[3] holds the first octet
            // (see PrintIpv4, which prints IPs[3].IPs[2].IPs[1].IPs[0]). Filling them in text
            // order hands the API a byte-reversed address: SetIPSuite accepts it and the CPU
            // never answers on the wire.
            output->IPs[3 - octet] = static_cast<BYTE>(value);
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

// Runs the acceptance command protocol against an ALREADY registered instance, without
// registering, powering, downloading or unregistering anything. It exists because the
// downloaded program lives in the instance memory: restarting the instance to run a plan
// would throw the download away.
int RunPlanOnRegisteredInstance(ISimulationRuntimeManager* manager, int argc, wchar_t* argv[])
{
    const std::wstring requestedName = ArgumentValue(argc, argv, L"--name", L"");
    if (requestedName.empty())
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"validate\",\"message\":\"--name is required.\"}\n";
        return 2;
    }

    const UINT32 registeredCount = manager->GetRegisteredInstancesCount();
    SInstanceInfo matchedInfo{};
    bool found = false;
    for (UINT32 index = 0; index < registeredCount; ++index)
    {
        SInstanceInfo info{};
        const ERuntimeErrorCode listCode = manager->GetRegisteredInstanceInfoAt(index, &info);
        if (listCode != SREC_OK)
        {
            std::wcout << L"{\"status\":\"failed\",\"stage\":\"list-instances\",\"registeredCount\":"
                       << registeredCount << ",\"listCode\":\"0x" << std::hex << static_cast<int>(listCode) << std::dec << L"\"}\n";
            return 1;
        }
        if (requestedName == info.Name)
        {
            matchedInfo = info;
            found = true;
            break;
        }
    }
    if (!found)
    {
        std::wcout << L"{\"status\":\"not-found\",\"requestedName\":";
        PrintJsonString(requestedName);
        std::wcout << L",\"registeredCount\":" << registeredCount << L"}\n";
        return 3;
    }

    IInstance* instance = nullptr;
    std::wstring mutableName = requestedName;
    const ERuntimeErrorCode createCode = manager->CreateInterface(mutableName.data(), &instance);
    if (createCode != SREC_OK || instance == nullptr)
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"attach\",\"createCode\":\"0x" << std::hex
                   << static_cast<int>(createCode) << std::dec << L"\"}\n";
        return 1;
    }

    std::wcout << L"{\"status\":\"ready\",\"stage\":\"attached\",\"instanceName\":";
    PrintJsonString(requestedName);
    std::wcout << L",\"cpuType\":";
    PrintJsonString(GetNameOfCPUType(instance->GetCPUType()));
    std::wcout << L",\"communicationInterface\":";
    PrintJsonString(GetNameOfCommunicationInterface(instance->GetCommunicationInterface()));
    std::wcout << L",\"operatingState\":";
    PrintJsonString(GetNameOfOperatingState(instance->GetOperatingState()));

    // The symbolic API resolves names against a shared-memory tag list. That list is filled by
    // UpdateTagList() reading the VPLC, and it is stale right after a program download, which
    // is why a symbolic read answers SREC_NOT_UP_TO_DATE (-47) even though the CPU runs the
    // downloaded program. Refresh it before the first symbolic read.
    ETagListDetails tagListDetails = SRTLD_NONE;
    bool hmiVisibleOnly = false;
    const ERuntimeErrorCode statusCode = instance->GetTagListStatus(&tagListDetails, &hmiVisibleOnly);
    const ERuntimeErrorCode updateCode = instance->UpdateTagList();
    std::wcout << L",\"tagListStatus\":";
    PrintCode(L"statusCode", statusCode);
    std::wcout << L",\"tagListUpdate\":";
    PrintCode(L"updateCode", updateCode);
    std::wcout << L",\"tagListNeedsUpdate\":";
    std::wcout << (tagListDetails == SRTLD_NONE ? L"true" : L"false");

    const UINT32 tagCount = instance->GetTagInfoCount();
    std::wcout << L",\"tagCount\":" << tagCount;
    if (tagCount > 0)
    {
        std::vector<STagInfo> tagInfos(tagCount);
        UINT32 written = 0;
        const ERuntimeErrorCode listCode = instance->GetTagInfos(tagCount, tagInfos.data(), &written);
        std::wcout << L",\"tagListCode\":";
        PrintCode(L"listCode", listCode);
        std::wcout << L",\"tags\":[";
        const UINT32 reportLimit = written < 12 ? written : 12;
        for (UINT32 index = 0; index < reportLimit; ++index)
        {
            if (index > 0) { std::wcout << L","; }
            std::wcout << L"\"";
            for (const wchar_t character : tagInfos[index].Name)
            {
                if (character == L'\0') { break; }
                if (character == L'"' || character == L'\\') { std::wcout << L'\\'; }
                std::wcout << character;
            }
            std::wcout << L"\"";
        }
        std::wcout << L"]";
    }
    std::wcout << L"}\n";
    std::wcout.flush();

    std::wstring command;
    while (std::getline(std::wcin, command))
    {
        if (command == L"stop" || command == L"quit") break;
        HandleAcceptanceCommand(instance, command);
    }

    // Only the interface is released: the instance, its power state and the downloaded
    // program are left exactly as they were found.
    const ERuntimeErrorCode destroyCode = DestroyInterface(instance);
    std::wcout << L"{\"status\":\"stopped\",\"stage\":\"detached\",";
    PrintCode(L"destroyCode", destroyCode);
    std::wcout << L"}\n";
    return destroyCode == SREC_OK ? 0 : 1;
}

// Read-only inspection of an already registered instance. Does not register,
// power on/off, download, or unregister the PLC.
int RunInspectRegisteredInstance(ISimulationRuntimeManager* manager, int argc, wchar_t* argv[])
{
    const std::wstring requestedName = ArgumentValue(argc, argv, L"--name", L"");
    if (requestedName.empty())
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"validate\",\"message\":\"--name is required for --inspect-registered-instance.\"}\n";
        return 2;
    }

    const UINT32 registeredCount = manager->GetRegisteredInstancesCount();
    SInstanceInfo matchedInfo{};
    bool found = false;
    ERuntimeErrorCode listCode = SREC_OK;
    for (UINT32 index = 0; index < registeredCount; ++index)
    {
        SInstanceInfo info{};
        listCode = manager->GetRegisteredInstanceInfoAt(index, &info);
        if (listCode != SREC_OK)
        {
            std::wcout << L"{\"status\":\"failed\",\"stage\":\"list-instances\",\"registeredCount\":"
                       << registeredCount << L",";
            PrintCode(L"listCode", listCode);
            std::wcout << L"}\n";
            return 1;
        }
        if (requestedName == info.Name)
        {
            matchedInfo = info;
            found = true;
            break;
        }
    }

    if (!found)
    {
        std::wcout << L"{\"status\":\"not-found\",\"requestedName\":";
        PrintJsonString(requestedName);
        std::wcout << L",\"registeredCount\":" << registeredCount << L"}\n";
        return 3;
    }

    IInstance* instance = nullptr;
    std::wstring mutableName = requestedName;
    const ERuntimeErrorCode createCode = manager->CreateInterface(mutableName.data(), &instance);
    if (createCode != SREC_OK || instance == nullptr)
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"create-read-interface\",\"requestedName\":";
        PrintJsonString(requestedName);
        std::wcout << L",";
        PrintCode(L"createCode", createCode);
        std::wcout << L"}\n";
        return 1;
    }

    WCHAR reportedName[DINSTANCE_NAME_MAX_LENGTH] = {};
    const ERuntimeErrorCode nameCode = instance->GetName(reportedName, DINSTANCE_NAME_MAX_LENGTH);
    const ECPUType cpuType = instance->GetCPUType();
    const ECommunicationInterface communicationInterface = instance->GetCommunicationInterface();
    const EOperatingState operatingState = instance->GetOperatingState();
    const UINT32 ipCount = instance->GetControllerIPCount();
    std::vector<UIP> addresses(ipCount);
    for (UINT32 index = 0; index < ipCount; ++index)
    {
        addresses[index] = instance->GetControllerIP(index);
    }

    const ERuntimeErrorCode destroyCode = DestroyInterface(instance);
    instance = nullptr;
    const bool success = nameCode == SREC_OK && destroyCode == SREC_OK;

    std::wcout << L"{\"status\":\"" << (success ? L"ok" : L"failed") << L"\",";
    std::wcout << L"\"instanceId\":" << matchedInfo.ID << L",\"requestedName\":";
    PrintJsonString(requestedName);
    std::wcout << L",\"name\":";
    PrintJsonString(reportedName);
    std::wcout << L",";
    PrintCode(L"nameCode", nameCode);
    std::wcout << L",\"cpuType\":";
    PrintJsonString(GetNameOfCPUType(cpuType));
    std::wcout << L",\"cpuTypeValue\":" << static_cast<int>(cpuType) << L",\"communicationInterface\":";
    PrintJsonString(GetNameOfCommunicationInterface(communicationInterface));
    std::wcout << L",\"communicationInterfaceValue\":" << static_cast<int>(communicationInterface)
               << L",\"operatingState\":";
    PrintJsonString(GetNameOfOperatingState(operatingState));
    std::wcout << L",\"operatingStateValue\":" << static_cast<int>(operatingState)
               << L",\"ipAddresses\":[";
    for (UINT32 index = 0; index < ipCount; ++index)
    {
        if (index > 0) std::wcout << L",";
        PrintIpv4(addresses[index]);
    }
    std::wcout << L"],\"registeredCount\":" << registeredCount << L",";
    PrintCode(L"destroyCode", destroyCode);
    std::wcout << L",\"mutatedRuntime\":false}\n";
    return success ? 0 : 1;
}

// Runs a tightly scoped logic check against one already registered, standard
// 1513 Softbus instance. Only Cmd_Enable is written; its original value is
// restored before the interface is released. The instance is never powered
// off, unregistered, or downloaded by this mode.
int RunBehavioralSmokeOnRegisteredInstance(ISimulationRuntimeManager* manager, int argc, wchar_t* argv[])
{
    const std::wstring requestedName = ArgumentValue(argc, argv, L"--name", L"");
    if (requestedName.empty())
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"validate\",\"message\":\"--name is required.\"}\n";
        return 2;
    }
    const UINT32 registeredCount = manager->GetRegisteredInstancesCount();
    if (registeredCount != 1)
    {
        std::wcout << L"{\"status\":\"blocked\",\"stage\":\"identity\",\"registeredCount\":" << registeredCount << L"}\n";
        return 3;
    }
    SInstanceInfo info{};
    const ERuntimeErrorCode infoCode = manager->GetRegisteredInstanceInfoAt(0, &info);
    if (infoCode != SREC_OK || requestedName != info.Name)
    {
        std::wcout << L"{\"status\":\"blocked\",\"stage\":\"identity\",\"requestedName\":";
        PrintJsonString(requestedName);
        std::wcout << L",\"registeredName\":";
        PrintJsonString(info.Name);
        std::wcout << L",";
        PrintCode(L"infoCode", infoCode);
        std::wcout << L"}\n";
        return 3;
    }

    IInstance* instance = nullptr;
    std::wstring mutableName = requestedName;
    const ERuntimeErrorCode createCode = manager->CreateInterface(mutableName.data(), &instance);
    if (createCode != SREC_OK || instance == nullptr)
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"attach\",";
        PrintCode(L"createCode", createCode);
        std::wcout << L"}\n";
        return 1;
    }

    const std::wstring cpuName = GetNameOfCPUType(instance->GetCPUType());
    const std::wstring interfaceName = GetNameOfCommunicationInterface(instance->GetCommunicationInterface());
    const std::wstring operatingState = GetNameOfOperatingState(instance->GetOperatingState());
    if (cpuName != L"1513" || interfaceName != L"Softbus" || operatingState != L"Run")
    {
        const ERuntimeErrorCode destroyCode = DestroyInterface(instance);
        std::wcout << L"{\"status\":\"blocked\",\"stage\":\"runtime-preflight\",\"cpuType\":";
        PrintJsonString(cpuName);
        std::wcout << L",\"communicationInterface\":";
        PrintJsonString(interfaceName);
        std::wcout << L",\"operatingState\":";
        PrintJsonString(operatingState);
        std::wcout << L",";
        PrintCode(L"destroyCode", destroyCode);
        std::wcout << L"}\n";
        return 3;
    }

    const std::wstring commandTagName = L"Cmd_Enable";
    std::vector<wchar_t> commandTag(commandTagName.begin(), commandTagName.end());
    commandTag.push_back(L'\0');
    const std::wstring statusTagName = L"Status_Active";
    std::vector<wchar_t> statusTag(statusTagName.begin(), statusTagName.end());
    statusTag.push_back(L'\0');
    bool initialCommand = false;
    bool initialStatus = false;
    const ERuntimeErrorCode readCommandCode = instance->ReadBool(commandTag.data(), &initialCommand);
    const ERuntimeErrorCode readStatusCode = instance->ReadBool(statusTag.data(), &initialStatus);
    if (readCommandCode != SREC_OK || readStatusCode != SREC_OK)
    {
        const ERuntimeErrorCode destroyCode = DestroyInterface(instance);
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"initial-read\",";
        PrintCode(L"readCommandCode", readCommandCode);
        std::wcout << L",";
        PrintCode(L"readStatusCode", readStatusCode);
        std::wcout << L",";
        PrintCode(L"destroyCode", destroyCode);
        std::wcout << L"}\n";
        return 1;
    }
    const bool originalStatus = initialStatus;

    auto waitForStatus = [&](bool expected, bool* observed) -> bool
    {
        const ULONGLONG deadline = GetTickCount64() + 5000;
        do
        {
            const ERuntimeErrorCode code = instance->ReadBool(statusTag.data(), observed);
            if (code != SREC_OK) return false;
            if (*observed == expected) return true;
            Sleep(100);
        } while (GetTickCount64() < deadline);
        return false;
    };

    bool disabledStatus = initialStatus;
    bool enabledStatus = initialStatus;
    bool restoredStatus = initialStatus;
    const ERuntimeErrorCode disableCode = instance->WriteBool(commandTag.data(), false);
    const bool disabledObserved = disableCode == SREC_OK && waitForStatus(false, &disabledStatus);
    const ERuntimeErrorCode enableCode = instance->WriteBool(commandTag.data(), true);
    const bool enabledObserved = enableCode == SREC_OK && waitForStatus(true, &enabledStatus);
    const ERuntimeErrorCode restoreCode = instance->WriteBool(commandTag.data(), initialCommand);
    const bool restoredObserved = restoreCode == SREC_OK && waitForStatus(initialCommand, &restoredStatus);
    bool finalCommand = false;
    const ERuntimeErrorCode finalCommandReadCode = instance->ReadBool(commandTag.data(), &finalCommand);
    const ERuntimeErrorCode destroyCode = DestroyInterface(instance);
    instance = nullptr;
    const bool success = disabledObserved && enabledObserved && restoreCode == SREC_OK && restoredObserved &&
                         finalCommandReadCode == SREC_OK && finalCommand == initialCommand && destroyCode == SREC_OK;

    std::wcout << L"{\"status\":\"" << (success ? L"passed" : L"failed") << L"\",\"stage\":\"behavior\",\"instanceName\":";
    PrintJsonString(requestedName);
    std::wcout << L",\"transport\":\"Softbus\",\"cpuType\":\"1513\",\"initialCommand\":" << (initialCommand ? L"true" : L"false")
               << L",\"initialStatus\":" << (originalStatus ? L"true" : L"false")
               << L",\"disabledStatus\":" << (disabledStatus ? L"true" : L"false")
               << L",\"disabledObserved\":" << (disabledObserved ? L"true" : L"false")
               << L",\"enabledStatus\":" << (enabledStatus ? L"true" : L"false")
               << L",\"enabledObserved\":" << (enabledObserved ? L"true" : L"false")
               << L",\"restoredStatus\":" << (restoredStatus ? L"true" : L"false")
               << L",\"restoredObserved\":" << (restoredObserved ? L"true" : L"false")
               << L",\"finalCommand\":" << (finalCommand ? L"true" : L"false")
               << L",\"runtimeMutation\":true,";
    PrintCode(L"disableCode", disableCode);
    std::wcout << L",";
    PrintCode(L"enableCode", enableCode);
    std::wcout << L",";
    PrintCode(L"restoreCode", restoreCode);
    std::wcout << L",";
    PrintCode(L"finalCommandReadCode", finalCommandReadCode);
    std::wcout << L",";
    PrintCode(L"destroyCode", destroyCode);
    std::wcout << L"}\n";
    return success ? 0 : 1;
}

// Exercises the TCP/IP path on a standard, temporary 1513-1 CPU.  This is
// deliberately separate from project acceptance: no project is downloaded.
int RunTcpIpDisposableProbe(ISimulationRuntimeManager* manager, int argc, wchar_t* argv[])
{
    const UINT32 timeoutMs = static_cast<UINT32>(std::stoul(ArgumentValue(argc, argv, L"--timeout-ms", L"60000")));
    const std::wstring ipText = ArgumentValue(argc, argv, L"--ip", L"192.168.200.1");
    const UINT32 registeredBefore = manager->GetRegisteredInstancesCount();
    ENetworkMode modeBefore = ENetworkMode::UNKNOWN_STATE;
    const ERuntimeErrorCode modeReadCode = manager->GetNetworkMode(&modeBefore);
    const ERuntimeErrorCode modeSetCode = manager->SetNetworkMode(ENetworkMode::TCPIP_SINGLE_ADAPTER);
    ENetworkMode modeAfter = ENetworkMode::UNKNOWN_STATE;
    const ERuntimeErrorCode modeVerifyCode = manager->GetNetworkMode(&modeAfter);
    // Runtime bindings require an administrator parent session. The Control
    // Panel already selects Ethernet 3 in single-adapter mode; do not mutate
    // that global setting for a local disposable probe.

    UIP ip{}; UIP mask{}; UIP gateway{};
    const bool parsed = ParseIp(ipText, &ip) && ParseIp(L"255.255.255.0", &mask) && ParseIp(L"0.0.0.0", &gateway);
    std::wstring instanceName = L"TIAClaudeTcpProbe_" + std::to_wstring(GetCurrentProcessId());
    IInstance* instance = nullptr;
    ERuntimeErrorCode registerCode = SREC_OK, powerOnCode = SREC_OK, ipCode = SREC_OK;
    ERuntimeErrorCode powerOffCode = SREC_OK, unregisterCode = SREC_OK, destroyCode = SREC_OK;
    bool poweredOn = false, unregistered = false;
    if (modeSetCode == SREC_OK && modeVerifyCode == SREC_OK &&
        modeAfter == ENetworkMode::TCPIP_SINGLE_ADAPTER && parsed)
    {
        registerCode = manager->RegisterInstance(SRCT_1513, instanceName.data(), &instance);
        if (registerCode == SREC_OK && instance != nullptr)
        {
            powerOnCode = instance->PowerOn(timeoutMs);
            poweredOn = powerOnCode == SREC_OK;
            if (poweredOn)
            {
                SIPSuite4 suite{}; suite.IPAddress = ip; suite.SubnetMask = mask; suite.DefaultGateway = gateway;
                ipCode = instance->SetIPSuite(0, suite, true);
                powerOffCode = instance->PowerOff(timeoutMs);
            }
            unregisterCode = instance->UnregisterInstance();
            unregistered = unregisterCode == SREC_OK;
            destroyCode = DestroyInterface(instance);
        }
    }
    const UINT32 registeredAfter = manager->GetRegisteredInstancesCount();
    const bool success = modeReadCode == SREC_OK && modeSetCode == SREC_OK && modeVerifyCode == SREC_OK &&
        modeAfter == ENetworkMode::TCPIP_SINGLE_ADAPTER && parsed &&
        registerCode == SREC_OK && poweredOn && ipCode == SREC_OK && powerOffCode == SREC_OK &&
        unregistered && destroyCode == SREC_OK && registeredAfter == registeredBefore;
    std::wcout << L"{\"status\":\"" << (success ? L"ready" : L"failed") << L"\",\"modeBefore\":"
        << static_cast<int>(modeBefore) << L",\"modeAfter\":" << static_cast<int>(modeAfter)
        << L",\"cpuType\":" << static_cast<int>(SRCT_1513) << L",\"ip\":";
    PrintJsonString(ipText); std::wcout << L",\"registeredBefore\":" << registeredBefore
        << L",\"registeredAfter\":" << registeredAfter << L",";
    PrintCode(L"modeReadCode", modeReadCode); std::wcout << L","; PrintCode(L"modeSetCode", modeSetCode);
    std::wcout << L","; PrintCode(L"modeVerifyCode", modeVerifyCode); std::wcout << L",\"bindingMutation\":\"skipped-local-only\",";
    PrintCode(L"registerCode", registerCode); std::wcout << L","; PrintCode(L"powerOnCode", powerOnCode);
    std::wcout << L","; PrintCode(L"ipCode", ipCode); std::wcout << L","; PrintCode(L"powerOffCode", powerOffCode);
    std::wcout << L","; PrintCode(L"unregisterCode", unregisterCode); std::wcout << L","; PrintCode(L"destroyCode", destroyCode);
    std::wcout << L"}\n";
    return success ? 0 : 1;
}

// Reference implementation of the TCP/IP acceptance flow. It is not reachable from wmain:
// its mapping/binding/IP logic was ported into RunLocalAcceptanceInstance, which is the
// path --register-acceptance actually takes.
[[maybe_unused]] int RunAcceptanceInstance(ISimulationRuntimeManager* manager, int argc, wchar_t* argv[])
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

int RunLocalAcceptanceInstance(ISimulationRuntimeManager* manager, int argc, wchar_t* argv[])
{
    const std::wstring instanceName = ArgumentValue(argc, argv, L"--name", L"TIAClaudeAcceptance_1513");
    const std::wstring cpuText = ArgumentValue(argc, argv, L"--cpu", L"1513");
    const std::wstring transport = ArgumentValue(argc, argv, L"--transport", L"softbus");
    const std::wstring ipText = ArgumentValue(argc, argv, L"--ip", L"192.168.0.1");
    const std::wstring maskText = ArgumentValue(argc, argv, L"--mask", L"255.255.255.0");
    const std::wstring gatewayText = ArgumentValue(argc, argv, L"--gateway", L"0.0.0.0");
    const UINT32 timeoutMs = static_cast<UINT32>(std::stoul(ArgumentValue(argc, argv, L"--timeout-ms", L"60000")));
    // Softbus does not select a network adapter. TCP/IP does: the needle names the Windows
    // adapter whose IE1 port the virtual CPU has to be bound to, otherwise the CPU never
    // answers on the wire even though its IP suite is configured.
    const std::wstring interfaceNeedle = ArgumentValue(argc, argv, L"--interface", L"Siemens PLCSIM Virtual Ethernet Adapter");
    ECPUType cpuType = SRCT_1500_Unspecified;
    if (cpuText == L"1511") cpuType = SRCT_1511;
    else if (cpuText == L"1513") cpuType = SRCT_1513;
    else if (cpuText == L"1515") cpuType = SRCT_1515;
    else if (cpuText == L"1517") cpuType = SRCT_1517;
    else { PrintProtocolFailure(L"validate-cpu", L"Only standard non-F CPU types 1511, 1513, 1515 and 1517 are permitted."); return 1; }

    UIP ip{}, mask{}, gateway{};
    if (!ParseIp(ipText, &ip) || !ParseIp(maskText, &mask) || !ParseIp(gatewayText, &gateway))
    { PrintProtocolFailure(L"parse-ip", L"Invalid IPv4 address, mask or gateway"); return 1; }

    const bool useSoftbus = transport == L"softbus";
    if (!useSoftbus && transport != L"tcpip-local")
    { PrintProtocolFailure(L"validate-transport", L"Transport must be softbus or tcpip-local."); return 1; }
    // Softbus does not select a Windows adapter; --interface belongs to tcpip-local only.
    // Reject the contradiction before any network-mode change or instance registration so
    // a mistyped acceptance call cannot start a CPU that was never meant to run.
    if (useSoftbus && HasArgument(argc, argv, L"--interface"))
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"unsupported-interface-argument\",\"requested\":";
        PrintJsonString(interfaceNeedle);
        std::wcout << L",\"reason\":\"Softbus does not select a Windows network adapter; omit --interface or use --transport tcpip-local.\"}\n";
        std::wcout.flush();
        return 1;
    }
    const ENetworkMode requestedMode = useSoftbus ? ENetworkMode::SOFTBUS : ENetworkMode::TCPIP_SINGLE_ADAPTER;
    ENetworkMode modeBefore = ENetworkMode::UNKNOWN_STATE;
    const ERuntimeErrorCode modeReadCode = manager->GetNetworkMode(&modeBefore);
    const ERuntimeErrorCode modeSetCode = manager->SetNetworkMode(requestedMode);
    ENetworkMode modeAfter = ENetworkMode::UNKNOWN_STATE;
    const ERuntimeErrorCode modeVerifyCode = manager->GetNetworkMode(&modeAfter);
    if (modeSetCode != SREC_OK || modeVerifyCode != SREC_OK || modeAfter != requestedMode)
    {
        std::wcout << L"{\"status\":\"failed\",\"stage\":\"set-network-mode\",";
        PrintCode(L"modeReadCode", modeReadCode); std::wcout << L","; PrintCode(L"modeSetCode", modeSetCode);
        std::wcout << L","; PrintCode(L"modeVerifyCode", modeVerifyCode); std::wcout << L"}\n"; return 1;
    }

    IInstance* instance = nullptr;
    const ERuntimeErrorCode registerCode = manager->RegisterInstance(cpuType, const_cast<wchar_t*>(instanceName.c_str()), &instance);
    if (registerCode != SREC_OK || instance == nullptr)
    { std::wcout << L"{\"status\":\"failed\",\"stage\":\"register-instance\","; PrintCode(L"registerCode", registerCode); std::wcout << L"}\n"; return 1; }

    ERuntimeErrorCode ipCode = SREC_OK;
    ERuntimeErrorCode mappingCode = SREC_OK;
    ERuntimeErrorCode bindingCode = SREC_OK;
    INT32 mappingReadback = -1;
    std::wstring controllerIp;
    std::wstring boundInterface;
    UINT boundInterfaceIndex = 0;
    // Order matters and is enforced by the runtime:
    //   - the IE1 mapping and the runtime binding need the instance STOPPED
    //     (SREC_INSTANCE_ALREADY_RUNNING, -72, if it is already running);
    //   - the IP suite needs the instance RUNNING (SREC_INSTANCE_NOT_RUNNING, -14, otherwise).
    if (!useSoftbus)
    {
        // The virtual CPU only answers on the wire when its IE1 port is mapped to a Windows
        // adapter and the runtime is bound to that same adapter. Without both calls the CPU
        // keeps its IP in the configuration but nothing ever reaches it.
        UINT interfaceCount = 0;
        manager->GetNetInterfaces(nullptr, &interfaceCount);
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
            std::wcout << L"{\"status\":\"failed\",\"stage\":\"select-interface\",\"requested\":";
            PrintJsonString(interfaceNeedle);
            std::wcout << L",\"interfaceCount\":" << interfaceCount << ",\"interfaces\":[";
            for (UINT index = 0; index < interfaceCount; ++index)
            {
                if (index > 0) { std::wcout << L","; }
                std::wcout << L"{\"name\":";
                PrintJsonString(interfaces[index].interfaceName);
                std::wcout << L",\"description\":";
                PrintJsonString(interfaces[index].interfaceDescription);
                std::wcout << L",\"index\":" << interfaces[index].interfaceIndex;
                std::wcout << L",\"isConnected\":" << (interfaces[index].isConnected ? "true" : "false");
                std::wcout << L",\"vSwitchBindingEnabled\":" << (interfaces[index].vSwitchBindingEnabled ? "true" : "false");
                std::wcout << L"}";
            }
            std::wcout << L"]}\n";
            std::wcout.flush();
            instance->PowerOff(timeoutMs); instance->UnregisterInstance(); DestroyInterface(instance); return 1;
        }
        boundInterface = selected->interfaceName;
        boundInterfaceIndex = selected->interfaceIndex;
        // The index overload is the reliable one: the user-friendly-name overload rejects the
        // OAM name because it carries the quotes and answers SREC_WRONG_COMMUNICATION_INTERFACE (-32).
        mappingCode = instance->SetNetInterfaceMapping(EPLCInterface::IE1, static_cast<DWORD>(selected->interfaceIndex));
        if (mappingCode == SREC_WRONG_COMMUNICATION_INTERFACE)
        {
            // In single-adapter mode an explicit PC interface is not accepted: the Control
            // Panel communication channel decides it. Zero clears any explicit mapping.
            mappingCode = instance->SetNetInterfaceMapping(EPLCInterface::IE1, static_cast<DWORD>(0));
        }
        mappingReadback = instance->GetNetInterfaceMapping(EPLCInterface::IE1);
        // Binding the runtime to zero selects local PC communication only. That is the mode
        // PLCSIM Advanced uses for TCP/IP single adapter, and it is the one in which the
        // virtual CPU is actually reachable: a non-zero index puts the virtual switch in
        // promiscuous mode, where the CPU's frames leave through the PC adapter and the
        // simulated CPU stops answering on the local host.
        bindingCode = manager->SetNetInterfaceBindings(0);
    }
    const ERuntimeErrorCode powerOnCode = instance->PowerOn(timeoutMs);
    if (!useSoftbus && powerOnCode == SREC_OK)
    {
        SIPSuite4 suite{}; suite.IPAddress = ip; suite.SubnetMask = mask; suite.DefaultGateway = gateway;
        ipCode = instance->SetIPSuite(0, suite, true);
        const UINT32 controllerIpCount = instance->GetControllerIPCount();
        if (controllerIpCount > 0)
        {
            const UIP actual = instance->GetControllerIP(0);
            controllerIp = std::to_wstring(static_cast<unsigned int>(actual.IPs[3])) + L"." +
                std::to_wstring(static_cast<unsigned int>(actual.IPs[2])) + L"." +
                std::to_wstring(static_cast<unsigned int>(actual.IPs[1])) + L"." +
                std::to_wstring(static_cast<unsigned int>(actual.IPs[0]));
        }
    }
    const bool ready = powerOnCode == SREC_OK &&
        (useSoftbus || (ipCode == SREC_OK && mappingCode == SREC_OK && bindingCode == SREC_OK));
    std::wcout << L"{\"status\":\"" << (ready ? L"ready" : L"failed") << L"\",\"stage\":\"" << (ready ? L"running" : L"configure") << L"\",\"instanceName\":";
    PrintJsonString(instanceName);
    std::wcout << L",\"cpuType\":" << static_cast<int>(cpuType) << L",\"interfaceName\":\"";
    if (useSoftbus) { std::wcout << L"PLCSIM"; } else { PrintJsonString(boundInterface); }
    std::wcout << L"\",\"interfaceDescription\":\"" << (useSoftbus ? L"Local Softbus; no network adapter" : L"Local TCP/IP via PLCSIM Control Panel <Local>") << L"\",\"interfaceIndex\":" << boundInterfaceIndex << L",\"ip\":";
    if (useSoftbus) std::wcout << L"null"; else PrintJsonString(ipText);
    std::wcout << L",\"networkMode\":\"" << (useSoftbus ? L"SOFTBUS" : L"TCPIP_SINGLE_ADAPTER") << L"\",\"binding\":\""
        << (useSoftbus ? L"local-only" : L"ie1-mapped") << L"\",";
    PrintCode(L"modeReadCode", modeReadCode); std::wcout << L","; PrintCode(L"modeSetCode", modeSetCode);
    std::wcout << L","; PrintCode(L"modeVerifyCode", modeVerifyCode); std::wcout << L","; PrintCode(L"registerCode", registerCode);
    std::wcout << L","; PrintCode(L"powerOnCode", powerOnCode); std::wcout << L","; PrintCode(L"ipCode", ipCode);
    std::wcout << L","; PrintCode(L"mappingCode", mappingCode); std::wcout << L","; PrintCode(L"bindingCode", bindingCode);
    std::wcout << L",\"mappingReadback\":" << static_cast<int>(mappingReadback);
    std::wcout << L",\"controllerIp\":";
    if (controllerIp.empty()) { std::wcout << L"null"; } else { PrintJsonString(controllerIp); }
    std::wcout << L"}\n";
    std::wcout.flush();
    if (!ready) { instance->PowerOff(timeoutMs); instance->UnregisterInstance(); DestroyInterface(instance); return 1; }

    std::wstring command;
    while (std::getline(std::wcin, command))
    {
        if (command == L"stop" || command == L"quit") break;
        HandleAcceptanceCommand(instance, command);
    }
    const ERuntimeErrorCode powerOffCode = instance->PowerOff(timeoutMs);
    const ERuntimeErrorCode unregisterCode = instance->UnregisterInstance();
    const ERuntimeErrorCode destroyCode = DestroyInterface(instance);
    const bool stopped = powerOffCode == SREC_OK && unregisterCode == SREC_OK && destroyCode == SREC_OK;
    std::wcout << L"{\"status\":\"" << (stopped ? L"stopped" : L"cleanup-failed") << L"\",";
    PrintCode(L"powerOffCode", powerOffCode); std::wcout << L","; PrintCode(L"unregisterCode", unregisterCode);
    std::wcout << L","; PrintCode(L"destroyCode", destroyCode); std::wcout << L"}\n";
    return stopped ? 0 : 1;
}
}

int wmain(int argc, wchar_t* argv[])
{
    const bool behavioralSmoke = HasArgument(argc, argv, L"--behavioral-smoke-existing");
    const bool planExisting = HasArgument(argc, argv, L"--plan-existing");
    const bool inspectRegisteredInstance = HasArgument(argc, argv, L"--inspect-registered-instance");
    const bool acceptance = HasArgument(argc, argv, L"--register-acceptance");
    const bool tcpIpProbe = HasArgument(argc, argv, L"--tcpip-disposable");
    ISimulationRuntimeManager* manager = nullptr;
    const ERuntimeErrorCode initializeCode = InitializeApi(&manager);
    if (initializeCode != SREC_OK || manager == nullptr)
    {
        std::wcout << L"{\"status\":\"initialization-failed\",";
        PrintCode(L"initializeCode", initializeCode);
        std::wcout << L"}\n";
        return 1;
    }

    const int exitCode = behavioralSmoke
        ? RunBehavioralSmokeOnRegisteredInstance(manager, argc, argv)
        : (planExisting
        ? RunPlanOnRegisteredInstance(manager, argc, argv)
        : (inspectRegisteredInstance
        ? RunInspectRegisteredInstance(manager, argc, argv)
        : (acceptance
            ? RunLocalAcceptanceInstance(manager, argc, argv)
            : (tcpIpProbe ? RunTcpIpDisposableProbe(manager, argc, argv) : RunDisposableProbe(manager, argc, argv)))));
    const ERuntimeErrorCode shutdownCode = ShutdownAndFreeApi(manager);
    if (exitCode != 0 || shutdownCode != SREC_OK)
    {
        std::wcerr << L"PLCSIM runtime shutdown code: 0x" << std::hex << static_cast<int>(shutdownCode) << std::dec << L"\n";
        return 1;
    }
    return 0;
}
