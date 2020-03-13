#include "hrr_rb_lxns.h"
#define _GNU_SOURCE 1
#include <sched.h>

VALUE rb_mHrrRbLxns;
VALUE rb_mHrrRbLxnsConst;

/*
 * A primitive wrapper around unshare(2) system call.
 * Disassociates parts of the caller process's execution context.
 *
 * == Synopsis:
 *   # Disassociates uts namespace
 *   File.readlink "/proc/self/ns/uts"       # => uts:[aaa]
 *   HrrRbLxns.__unshare__ HrrRbLxns::NEWUTS # => 0
 *   File.readlink "/proc/self/ns/uts"       # => uts:[xxx]
 *
 *   # Disassociates uts and mount namespaces
 *   File.readlink "/proc/self/ns/uts"                          # => uts:[aaa]
 *   File.readlink "/proc/self/ns/mnt"                          # => mnt:[bbb]
 *   HrrRbLxns.__unshare__ HrrRbLxns::NEWUTS | HrrRbLxns::NEWNS # => 0
 *   File.readlink "/proc/self/ns/uts"                          # => uts:[xxx]
 *   File.readlink "/proc/self/ns/mnt"                          # => mnt:[yyy]
 *
 * @param flags [Integer] Represents the namespaces to disassociate.
 * @return [Integer] 0.
 * @raise [TypeError] In case the given flags cannot be converted to integer.
 * @raise [Errno::EXXX]  In case unshare(2) system call failed.
 */
VALUE
hrr_rb_lxns_unshare(VALUE self, VALUE flags)
{
  if (unshare(NUM2INT(flags)) < 0)
    rb_sys_fail("unshare");

  return INT2FIX(0);
}

void
Init_hrr_rb_lxns(void)
{
  rb_mHrrRbLxns = rb_define_module("HrrRbLxns");

  rb_define_singleton_method(rb_mHrrRbLxns, "__unshare__", hrr_rb_lxns_unshare, 1);

  rb_mHrrRbLxnsConst = rb_define_module_under(rb_mHrrRbLxns, "Constants");
  rb_include_module(rb_mHrrRbLxns, rb_mHrrRbLxnsConst);

#ifdef CLONE_NEWIPC
  /* Represents ipc namespace. */
  rb_define_const(rb_mHrrRbLxnsConst, "NEWIPC", INT2FIX(CLONE_NEWIPC));
#endif
#ifdef CLONE_NEWNS
  /* Represents mount namespace. */
  rb_define_const(rb_mHrrRbLxnsConst, "NEWNS", INT2FIX(CLONE_NEWNS));
#endif
#ifdef CLONE_NEWNET
  /* Represents network namespace. */
  rb_define_const(rb_mHrrRbLxnsConst, "NEWNET", INT2FIX(CLONE_NEWNET));
#endif
#ifdef CLONE_NEWPID
  /* Represents pid namespace. */
  rb_define_const(rb_mHrrRbLxnsConst, "NEWPID", INT2FIX(CLONE_NEWPID));
#endif
#ifdef CLONE_NEWUTS
  /* Represents uts namespace. */
  rb_define_const(rb_mHrrRbLxnsConst, "NEWUTS", INT2FIX(CLONE_NEWUTS));
#endif
#ifdef CLONE_NEWUSER
  /* Represents user namespace. */
  rb_define_const(rb_mHrrRbLxnsConst, "NEWUSER", INT2FIX(CLONE_NEWUSER));
#endif
#ifdef CLONE_NEWCGROUP
  /* Represents cgroup namespace. */
  rb_define_const(rb_mHrrRbLxnsConst, "NEWCGROUP", INT2FIX(CLONE_NEWCGROUP));
#endif
#ifdef CLONE_NEWTIME
  /* Represents time namespace. */
  rb_define_const(rb_mHrrRbLxnsConst, "NEWTIME", INT2FIX(CLONE_NEWTIME));
#endif
}
