#ifndef _SYS_SHM_H
#define _SYS_SHM_H

#include "../../private/size_t.h"
#include "../../private/time_t.h"
#include "../../private/pid_t.h"
#include "../../private/ipc_perm.h"

typedef unsigned short shmatt_t;

struct shmid_ds {
  struct ipc_perm shm_perm;
  size_t shm_segsz;
  pid_t shm_lpid;
  pid_t shm_cpid;
  shmatt_t shm_nattch;
  time_t shm_atime;
  time_t shm_dtime;
  time_t shm_ctime;
};

#endif /* _SYS_SHM_H */
