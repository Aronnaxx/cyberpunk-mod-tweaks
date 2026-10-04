// SysMemInfo - exposes Windows memory status to scripts (redscript and CET Lua).
// Global functions, all returning Float megabytes:
//   SysMem_AvailPhysMB()     free physical RAM
//   SysMem_TotalPhysMB()     installed physical RAM (usable)
//   SysMem_AvailCommitMB()   commit charge still available (RAM + page file)
//   SysMem_CommitLimitMB()   commit limit (RAM + page file)
//   SysMem_ProcessCommitMB() memory committed by the game process
// CET: Game.SysMem_AvailPhysMB()

#include <RED4ext/RED4ext.hpp>

#include <Windows.h>
#include <Psapi.h>

namespace
{
constexpr float kMB = 1024.0f * 1024.0f;

MEMORYSTATUSEX QueryStatus()
{
    MEMORYSTATUSEX status{};
    status.dwLength = sizeof(status);
    GlobalMemoryStatusEx(&status);
    return status;
}

void Return(void* aOut, float aValue)
{
    if (aOut)
    {
        *static_cast<float*>(aOut) = aValue;
    }
}

void AvailPhysMB(RED4ext::IScriptable*, RED4ext::CStackFrame* aFrame, void* aOut, int64_t)
{
    aFrame->code++;
    Return(aOut, static_cast<float>(QueryStatus().ullAvailPhys) / kMB);
}

void TotalPhysMB(RED4ext::IScriptable*, RED4ext::CStackFrame* aFrame, void* aOut, int64_t)
{
    aFrame->code++;
    Return(aOut, static_cast<float>(QueryStatus().ullTotalPhys) / kMB);
}

void AvailCommitMB(RED4ext::IScriptable*, RED4ext::CStackFrame* aFrame, void* aOut, int64_t)
{
    aFrame->code++;
    Return(aOut, static_cast<float>(QueryStatus().ullAvailPageFile) / kMB);
}

void CommitLimitMB(RED4ext::IScriptable*, RED4ext::CStackFrame* aFrame, void* aOut, int64_t)
{
    aFrame->code++;
    Return(aOut, static_cast<float>(QueryStatus().ullTotalPageFile) / kMB);
}

void ProcessCommitMB(RED4ext::IScriptable*, RED4ext::CStackFrame* aFrame, void* aOut, int64_t)
{
    aFrame->code++;
    PROCESS_MEMORY_COUNTERS_EX counters{};
    counters.cb = sizeof(counters);
    float value = 0.0f;
    if (GetProcessMemoryInfo(GetCurrentProcess(), reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&counters),
                             sizeof(counters)))
    {
        value = static_cast<float>(counters.PrivateUsage) / kMB;
    }
    Return(aOut, value);
}

void Register(RED4ext::CRTTISystem* aRtti, const char* aName, RED4ext::ScriptingFunction_t<void*> aFunc)
{
    auto func = RED4ext::CGlobalFunction::Create(aName, aName, aFunc);
    func->flags = {.isNative = true, .isStatic = true};
    func->SetReturnType("Float");
    aRtti->RegisterFunction(func);
}

void PostRegisterTypes()
{
    auto rtti = RED4ext::CRTTISystem::Get();
    Register(rtti, "SysMem_AvailPhysMB", &AvailPhysMB);
    Register(rtti, "SysMem_TotalPhysMB", &TotalPhysMB);
    Register(rtti, "SysMem_AvailCommitMB", &AvailCommitMB);
    Register(rtti, "SysMem_CommitLimitMB", &CommitLimitMB);
    Register(rtti, "SysMem_ProcessCommitMB", &ProcessCommitMB);
}

void RegisterTypes()
{
}
} // namespace

RED4EXT_C_EXPORT bool RED4EXT_CALL Main(RED4ext::v1::PluginHandle, RED4ext::v1::EMainReason aReason,
                                        const RED4ext::v1::Sdk*)
{
    if (aReason == RED4ext::v1::EMainReason::Load)
    {
        auto rtti = RED4ext::CRTTISystem::Get();
        rtti->AddRegisterCallback(RegisterTypes);
        rtti->AddPostRegisterCallback(PostRegisterTypes);
    }
    return true;
}

RED4EXT_C_EXPORT void RED4EXT_CALL Query(RED4ext::v1::PluginInfo* aInfo)
{
    aInfo->name = L"SysMemInfo";
    aInfo->author = L"cyberpunk-mod-patches";
    aInfo->version = RED4EXT_V1_SEMVER(1, 0, 0);
    aInfo->runtime = RED4EXT_V1_RUNTIME_VERSION_LATEST;
    aInfo->sdk = RED4EXT_V1_SDK_VERSION_CURRENT;
}

RED4EXT_C_EXPORT uint32_t RED4EXT_CALL Supports()
{
    return RED4EXT_API_VERSION_1;
}
