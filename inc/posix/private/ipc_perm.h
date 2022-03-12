#ifndef _PRIVATE_IPC_PERM_H
#define _PRIVATE_IPC_PERM_H

#include "uid_t.h"
#include "gid_t.h"
#include "mode_t.h"

struct ipc_perm {
  uid_t uid;
  gid_t gid;
  uid_t cuid;
  gid_t cgid;
  mode_t mode;
};

#endif /* _PRIVATE_IPC_PERM_H */
