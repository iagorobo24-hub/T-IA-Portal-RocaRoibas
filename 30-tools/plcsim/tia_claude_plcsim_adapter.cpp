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
    bool registered = false;
    bool unregistered = false;
    if (registerDisposable)
    {
        registerCode = manager->RegisterInstance(SRCT_1516F, instanceName.data(), &instance);
        registered = registerCode == SREC_OK && instance != nullptr;
        if (registered)
        {
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
        (!registerDisposable || (registered && unregistered && destroyCode == SREC_OK && registeredAfter == registeredBefore));

    std::wcout << L"{\"status\":\"" << (success ? L"ready" : L"failed") << L"\",";
    std::wcout << L"\"registeredBefore\":" << registeredBefore << L",";
    std::wcout << L"\"registeredAfter\":" << registeredAfter << L",";
    std::wcout << L"\"registerDisposable\":" << (registerDisposable ? L"true" : L"false") << L",";
    std::wcout << L"\"instanceName\":";
    PrintJsonString(instanceName);
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
