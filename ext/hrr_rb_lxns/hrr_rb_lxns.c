#include "hrr_rb_lxns.h"

VALUE rb_mHrrRbLxns;

void
Init_hrr_rb_lxns(void)
{
  rb_mHrrRbLxns = rb_define_module("HrrRbLxns");
}
