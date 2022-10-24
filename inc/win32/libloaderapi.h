#ifndef _LIBLOADERAPI_H
#define _LIBLOADERAPI_H

HMODULE LoadLibraryExA(LPCSTR lpLibFileName, HANDLE hFile, DWORD dwFlags);
BOOL FreeLibrary(HMODULE hLibModule);
DWORD GetModuleFileNameA(HMODULE hModule, LPSTR lpFilename, DWORD nSize);

#endif /* _LIBLOADERAPI_H */
