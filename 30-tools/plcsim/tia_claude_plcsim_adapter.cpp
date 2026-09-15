#include <windows.h>
#include <iostream>
#include <string>

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
}

int wmain(int argc, wchar_t* argv[])
{
    const bool registerDisposable = argc > 1 && std::wstring(argv[1]) == L"--register-disposable";
    const bool registerInspect = argc > 1 && std::wstring(argv[1]) == L"--register-inspect";
    const bool powerOnDisposable = argc > 1 && std::wstring(argv[1]) == L"--power-on-disposable";
    ISimulationRuntimeManager* manager = nullptr;
    const ERuntimeErrorCode initializeCode = InitializeApi(&manager);
    if (initializeCode != SREC_OK || manager == nullptr)
    {
        std::wcout << L"{\"status\":\"initialization-failed\",";
        PrintCode(L"initializeCode", initializeCode);
        std::wcout << L"}\n";
        return 1;
    }

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
            // This acceptance adapter deliberately stops before PowerOn. It
            // proves only instance lifecycle, never runtime behavior.
            unregisterCode = instance->UnregisterInstance();
            unregistered = unregisterCode == SREC_OK;
            destroyCode = DestroyInterface(instance);
            instance = nullptr;
        }
    }

    const UINT32 registeredAfter = manager->GetRegisteredInstancesCount();
    const ERuntimeErrorCode shutdownCode = ShutdownAndFreeApi(manager);
    const bool success = shutdownCode == SREC_OK &&
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
    std::wcout << L"\"inspectedControllerIpCount\":" << inspectedControllerIpCount;
    std::wcout << L",";
    PrintCode(L"powerOnCode", powerOnCode);
    std::wcout << L",";
    PrintCode(L"powerOffCode", powerOffCode);
    std::wcout << L",";
    PrintCode(L"registerCode", registerCode);
    std::wcout << L",";
    PrintCode(L"unregisterCode", unregisterCode);
    std::wcout << L",";
    PrintCode(L"destroyCode", destroyCode);
    std::wcout << L",";
    PrintCode(L"shutdownCode", shutdownCode);
    std::wcout << L"}\n";
    return success ? 0 : 1;
}
