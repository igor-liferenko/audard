/*******************************************************************************
* callmodule.c                                                                 *
* Part of the {alsa-}scdcomp{-alsa} collection                                 *
*                                                                              *
* Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 *
* This program is free software, released under the GNU General Public License.*
* NO WARRANTY; for license information see the file LICENSE                    *
*******************************************************************************/

// http://stackoverflow.com/questions/21629045/capturing-user-space-assembly-with-ftrace-and-kprobes-by-using-virtual-address/22052390#22052390

#include <linux/module.h>
#include <linux/slab.h> //kzalloc
#include <linux/syscalls.h> // SIGCHLD, ... sys_wait4, ...
#include <linux/kallsyms.h> // kallsyms_lookup, print_symbol
#include <linux/highmem.h> // ‘kmap_atomic’ (via pte_offset_map)
#include <asm/io.h> // page_to_phys (arch/x86/include/asm/io.h)

MODULE_LICENSE("GPL");
MODULE_AUTHOR("sdaau");
static char *callmodule_userprog = "/path/to/program";
module_param(callmodule_userprog, charp, 0000);
MODULE_PARM_DESC(callmodule_userprog, "absolute path to executable");
// Note: by defining like this - trying to add more elements
// to array through command line, will result with:
// "callmodule_useraddrs: can only take 2 arguments":
#define NUM_USER_ADDRS 2
static unsigned long callmodule_useraddrs[NUM_USER_ADDRS] = { 0, 0 };
static int callmodule_useraddrs_argc = 0;
module_param_array(callmodule_useraddrs, long, &callmodule_useraddrs_argc, 0000);
MODULE_PARM_DESC(myintArray, "Array of max 2 instruction addresses (ulong) in user-space executable");
static unsigned long long callmodule_physaddrs[NUM_USER_ADDRS] = { 0, 0 };

struct subprocess_infoB; // forward declare
// global variable - to avoid intervening too much in the return of call_usermodehelperB:
static int callmodule_pid;
// global variable - to get the entire structure:
static struct subprocess_infoB* callmodule_infoB;

#define TRY_USE_KPROBES 0 // 1 // enable/disable kprobes usage code

#include <linux/kprobes.h> // enable_kprobe
// for hardware breakpoint:
#include <linux/perf_event.h>
#include <linux/hw_breakpoint.h>
static struct perf_event *callmodule_hbps[NUM_USER_ADDRS];


// these helper macros so we can print out the
// hex content of defines as strings, since
// print_symbol will accept only one argument:
#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)

// use sudo cat /proc/kallsyms | grep [funcnamesymbol] to find these:

#define _PTR_wait_for_helper         0xc1065b60
#define _PTR_____call_usermodehelper 0xc1065ed0

#if TRY_USE_KPROBES
#define _PTR_create_trace_probe 0xc10d5120
#define _PTR_find_probe_event   0xc10d41e0
#endif


// define a modified struct (with extra fields) here:
struct subprocess_infoB {
  struct work_struct work;
  struct completion *complete;
  char *path;
  char **argv;
  char **envp;
  int wait; //enum umh_wait wait;
  int retval;
  int (*init)(struct subprocess_info *info);
  void (*cleanup)(struct subprocess_info *info);
  void *data;
  pid_t pid;
  struct task_struct *task;
  unsigned long long last_page_physaddr;
};

// forward declare:
struct subprocess_infoB *call_usermodehelper_setupB(char *path, char **argv,
                          char **envp, gfp_t gfp_mask);

static inline int
call_usermodehelper_fnsB(char *path, char **argv, char **envp,
            int wait, //enum umh_wait wait,
            int (*init)(struct subprocess_info *info),
            void (*cleanup)(struct subprocess_info *), void *data)
{
  struct subprocess_info *info;
  struct subprocess_infoB *infoB;
  gfp_t gfp_mask = (wait == UMH_NO_WAIT) ? GFP_ATOMIC : GFP_KERNEL;
  int ret;

  populate_rootfs_wait(); // is in linux-headers-2.6.38-16-generic/include/linux/kmod.h

  infoB = call_usermodehelper_setupB(path, argv, envp, gfp_mask);
  printk(KBUILD_MODNAME ":a: pid %d\n", infoB->pid);
  info = (struct subprocess_info *) infoB;

  if (info == NULL)
      return -ENOMEM;

  call_usermodehelper_setfns(info, init, cleanup, data);
  printk(KBUILD_MODNAME ":b: pid %d\n", infoB->pid);

  // this must be called first, before infoB->pid is populated (by __call_usermodehelperB):
  ret = call_usermodehelper_exec(info, wait);

  // assign global pid here, so rest of the code has it:
  callmodule_pid = infoB->pid;
  // in fact, assign globally infoB, so rest of the code has it:
  callmodule_infoB = infoB;

  printk(KBUILD_MODNAME ":c: pid %d\n", callmodule_pid);

  return ret;
}

static inline int
call_usermodehelperB(char *path, char **argv, char **envp, int wait) //enum umh_wait wait)
{
  return call_usermodehelper_fnsB(path, argv, envp, wait,
                     NULL, NULL, NULL);
}

/* This is run by khelper thread  */
static void __call_usermodehelperB(struct work_struct *work)
{
  struct subprocess_infoB *sub_infoB =
      container_of(work, struct subprocess_infoB, work);
  int wait = sub_infoB->wait; // enum umh_wait wait = sub_info->wait;
  pid_t pid;
  struct subprocess_info *sub_info;
  // hack - declare function pointers, to use for wait_for_helper/____call_usermodehelper
  int (*ptrwait_for_helper)(void *data);
  int (*ptr____call_usermodehelper)(void *data);
  // assign function pointers to verbatim addresses as obtained from /proc/kallsyms
  int killret;
  struct task_struct *spawned_task;
  ptrwait_for_helper = (void *)_PTR_wait_for_helper;
  ptr____call_usermodehelper = (void *)_PTR_____call_usermodehelper;

  sub_info = (struct subprocess_info *)sub_infoB;

  /* CLONE_VFORK: wait until the usermode helper has execve'd
   * successfully We need the data structures to stay around
   * until that is done.  */
  if (wait == UMH_WAIT_PROC)
      pid = kernel_thread((*ptrwait_for_helper), sub_info, //(wait_for_helper, sub_info,
                  CLONE_FS | CLONE_FILES | SIGCHLD);
  else
      pid = kernel_thread((*ptr____call_usermodehelper), sub_info, //(____call_usermodehelper, sub_info,
                  CLONE_VFORK | SIGCHLD);

  spawned_task = pid_task(find_vpid(pid), PIDTYPE_PID);

  // stop/suspend/pause task
  killret = kill_pid(find_vpid(pid), SIGSTOP, 1); // if killret = -3 here, then p/spawned_task is NULL; but even if it is 0, process is mostly runnable!
  if (spawned_task!=NULL) {
    // this does explicitly force that a stopped state is read, but does it stop the process really, if the above signal via kill_pid failed?
    spawned_task->state = __TASK_STOPPED;
    printk(KBUILD_MODNAME ": : exst %d exco %d exsi %d diex %d inex %d inio %d\n", spawned_task->exit_state, spawned_task->exit_code, spawned_task->exit_signal, spawned_task->did_exec, spawned_task->in_execve, spawned_task->in_iowait);
  }
  printk(KBUILD_MODNAME ": : (kr: %d)\n", killret);
  printk(KBUILD_MODNAME ": : pid %d (%p) (%s)\n", pid, spawned_task,
    (spawned_task!=NULL)?((spawned_task->state==-1)?"unrunnable":((spawned_task->state==0)?"runnable":"stopped")):"null" );
  // grab and save the pid (and task_struct) here:
  sub_infoB->pid = pid;
  sub_infoB->task = spawned_task;
    switch (wait) {
    case UMH_NO_WAIT:
        call_usermodehelper_freeinfo(sub_info);
        break;
    case UMH_WAIT_PROC:
        if (pid > 0)
            break;
        /* FALLTHROUGH */
    case UMH_WAIT_EXEC:
        if (pid < 0)
            sub_info->retval = pid;
        complete(sub_info->complete);
    }
}

struct subprocess_infoB *call_usermodehelper_setupB(char *path, char **argv,
                          char **envp, gfp_t gfp_mask)
{
    struct subprocess_infoB *sub_infoB;
    sub_infoB = kzalloc(sizeof(struct subprocess_infoB), gfp_mask);
    if (!sub_infoB)
        goto out;

    INIT_WORK(&sub_infoB->work, __call_usermodehelperB);
    sub_infoB->path = path;
    sub_infoB->argv = argv;
    sub_infoB->envp = envp;
  out:
    return sub_infoB;
}

#if TRY_USE_KPROBES
// copy from /kernel/trace/trace_probe.c (is unexported)
int traceprobe_command(const char *buf, int (*createfn)(int, char **))
{
  char **argv;
  int argc, ret;

  argc = 0;
  ret = 0;
  argv = argv_split(GFP_KERNEL, buf, &argc);
  if (!argv)
    return -ENOMEM;

  if (argc)
    ret = createfn(argc, argv);

  argv_free(argv);

  return ret;
}

// copy from kernel/trace/trace_kprobe.c?v=2.6.38 (is unexported)
#define TP_FLAG_TRACE   1
#define TP_FLAG_PROFILE 2
typedef void (*fetch_func_t)(struct pt_regs *, void *, void *);
struct fetch_param {
  fetch_func_t    fn;
  void *data;
};
typedef int (*print_type_func_t)(struct trace_seq *, const char *, void *, void *);
enum {
  FETCH_MTD_reg = 0,
  FETCH_MTD_stack,
  FETCH_MTD_retval,
  FETCH_MTD_memory,
  FETCH_MTD_symbol,
  FETCH_MTD_deref,
  FETCH_MTD_END,
};
// Fetch type information table * /
struct fetch_type {
  const char      *name;          /* Name of type */
  size_t          size;           /* Byte size of type */
  int             is_signed;      /* Signed flag */
  print_type_func_t       print;  /* Print functions */
  const char      *fmt;           /* Fromat string */
  const char      *fmttype;       /* Name in format file */
  // Fetch functions * /
  fetch_func_t    fetch[FETCH_MTD_END];
};
struct probe_arg {
  struct fetch_param      fetch;
  struct fetch_param      fetch_size;
  unsigned int            offset; /* Offset from argument entry */
  const char              *name;  /* Name of this argument */
  const char              *comm;  /* Command of this argument */
  const struct fetch_type *type;  /* Type of this argument */
};
struct trace_probe {
  struct list_head        list;
  struct kretprobe        rp;     /* Use rp.kp for kprobe use */
  unsigned long           nhit;
  unsigned int            flags;  /* For TP_FLAG_* */
  const char              *symbol;        /* symbol name */
  struct ftrace_event_class       class;
  struct ftrace_event_call        call;
  ssize_t                 size;           /* trace entry size */
  unsigned int            nr_args;
  struct probe_arg        args[];
};
static  int probe_is_return(struct trace_probe *tp)
{
  return tp->rp.handler != NULL;
}
static int probe_event_enable(struct ftrace_event_call *call)
{
  struct trace_probe *tp = (struct trace_probe *)call->data;

  tp->flags |= TP_FLAG_TRACE;
  if (probe_is_return(tp))
    return enable_kretprobe(&tp->rp);
  else
    return enable_kprobe(&tp->rp.kp);
}
#define KPROBE_EVENT_SYSTEM "kprobes"
#endif // TRY_USE_KPROBES

// <<<<<<<<<<<<<<<<<<<<<<

// http://stackoverflow.com/questions/8980193/
static struct page *walk_page_table(unsigned long addr, struct task_struct *intask)
{
  pgd_t *pgd;
  pte_t *ptep, pte;
  pud_t *pud;
  pmd_t *pmd;

  struct page *page = NULL;
  struct mm_struct *mm = intask->mm;

  callmodule_infoB->last_page_physaddr = 0ULL; // reset here, in case of early exit

  printk(KBUILD_MODNAME ": walk_ 0x%lx ", addr);

  pgd = pgd_offset(mm, addr);
  if (pgd_none(*pgd) || pgd_bad(*pgd))
    goto out;
  printk(KBUILD_MODNAME ": Valid pgd ");

  pud = pud_offset(pgd, addr);
  if (pud_none(*pud) || pud_bad(*pud))
    goto out;
  printk( ": Valid pud");

  pmd = pmd_offset(pud, addr);
  if (pmd_none(*pmd) || pmd_bad(*pmd))
    goto out;
  printk( ": Valid pmd");

  ptep = pte_offset_map(pmd, addr);
  if (!ptep)
    goto out;
  pte = *ptep;

  page = pte_page(pte);
  if (page) {
    callmodule_infoB->last_page_physaddr = (unsigned long long)page_to_phys(page);
    printk( ": page frame struct is @ %p; *virtual (page_address) @ %p (is_vmalloc_addr %d virt_addr_valid %d virt_to_phys 0x%llx) page_to_pfn %lx page_to_phys 0x%llx", page, page_address(page), is_vmalloc_addr((void*)page_address(page)), virt_addr_valid(page_address(page)), (unsigned long long)virt_to_phys(page_address(page)), page_to_pfn(page), callmodule_infoB->last_page_physaddr);
  }

  //~ pte_unmap(ptep);

out:
  printk("\n");
  return page;
}

// http://stackoverflow.com/questions/19725900/
static void sample_hbp_handler(struct perf_event *bp,
             struct perf_sample_data *data,
             struct pt_regs *regs)
{
  trace_printk(KBUILD_MODNAME ": hwbp hit: id [%llu]\n", bp->id );
  //~ unregister_hw_breakpoint(bp); // not here; avoid ftrace printouts
}

// ----------------------
// NB: returning negative values from init, means module shouldn't load

static int __init callmodule_init(void)
{
  int ret = 0;
  char *argv[] = {callmodule_userprog, "2", NULL };
  char *envp[] = {"HOME=/", "PATH=/sbin:/usr/sbin:/bin:/usr/bin", NULL };
  struct task_struct *p;
  struct task_struct *par;
  struct task_struct *pc;
  struct list_head *children_list_head;
  struct list_head *cchildren_list_head;
  char *state_str;
  unsigned long offset, taddr;
  #if TRY_USE_KPROBES
  // unexported - via function pointer:
  // note: create_trace_probe is in kallsyms, but traceprobe_command isn't
  int (*ptr_create_trace_probe)(int argc, char **argv); // must have proper signature here!
  struct trace_probe* (*ptr_find_probe_event)(const char *event, const char *group);
  //int (*ptr_probe_event_enable)(struct ftrace_event_call *call); // not exported, copy
  char trcmd[256] = "";
  struct trace_probe *tp;
  #endif //TRY_USE_KPROBES
  struct perf_event_attr attrs[NUM_USER_ADDRS];
  int i, num_user_addrs_valid = 0;

  printk(KBUILD_MODNAME ": > init: %s @ ", callmodule_userprog);
  for (i=0; i<NUM_USER_ADDRS; i++) {
    if (callmodule_useraddrs[i] != 0) num_user_addrs_valid++;
    printk("0x%08lx ", callmodule_useraddrs[i]);
  }
  printk("\n");
  if (num_user_addrs_valid == 0) {
    printk(KBUILD_MODNAME ": no valid user space addresses to track - exiting\n");
    return -1;
  }

  // note - only one argument allowed for print_symbol
  print_symbol(KBUILD_MODNAME ": symbol @ " STR(_PTR_wait_for_helper) " is %s\n", _PTR_wait_for_helper); // shows wait_for_helper+0x0/0xb0
  print_symbol(KBUILD_MODNAME ": symbol @ " STR(_PTR_____call_usermodehelper) " is %s\n", _PTR_____call_usermodehelper); // shows ____call_usermodehelper+0x0/0x90

  #if TRY_USE_KPROBES
  ptr_create_trace_probe = (void *)_PTR_create_trace_probe;
  ptr_find_probe_event = (void *)_PTR_find_probe_event;
  print_symbol(KBUILD_MODNAME ": symbol @ " STR(_PTR_create_trace_probe) " is %s\n", _PTR_create_trace_probe); // shows create_trace_probe+0x0/0x590
  #endif

  ret = call_usermodehelperB(callmodule_userprog, argv, envp, UMH_WAIT_EXEC); //UMH_WAIT_PROC); //UMH_WAIT_EXEC);
  if (ret != 0) {
    printk(KBUILD_MODNAME ": error in call to usermodehelper: %i\n", ret);
    return -1;
  }
  else
    printk(KBUILD_MODNAME ": everything all right; pid %d (%d)\n", callmodule_pid, callmodule_infoB->pid);
  tracing_on(); // earlier, so trace_printk of handler is caught!
  // find the task:
  rcu_read_lock();
  p = pid_task(find_vpid(callmodule_pid), PIDTYPE_PID);
  rcu_read_unlock();
  if (p == NULL) {
    printk(KBUILD_MODNAME ": p is NULL - exiting\n");
    return -1;
  }
  // (out here that task is typically in runnable state, if not stopped)
  state_str = (p->state==-1)?"unrunnable":((p->state==0)?"runnable":"stopped");
  printk(KBUILD_MODNAME ": pid task a: %p c: %s p: [%d] s: %s\n",
    p, p->comm, p->pid, state_str);

  // find parent task:
  par = p->parent;
  if (par == NULL) {
    printk(KBUILD_MODNAME ": par is NULL - exiting\n");
    return -1;
  }
  state_str = (par->state==-1)?"unrunnable":((par->state==0)?"runnable":"stopped");
  printk(KBUILD_MODNAME ": parent task a: %p c: %s p: [%d] s: %s\n",
    par, par->comm, par->pid, state_str);

  // iterate through parent's (and our task's) child processes:
  rcu_read_lock(); // read_lock(&tasklist_lock);
  list_for_each(children_list_head, &par->children){
    p = list_entry(children_list_head, struct task_struct, sibling);
    printk(KBUILD_MODNAME ": - %s [%d] \n", p->comm, p->pid);
    // note: trying to print "%p",p here results with oops/segfault:
    // printk(KBUILD_MODNAME ": - %s [%d] %p\n", p->comm, p->pid, p);
    if (p->pid == callmodule_pid) {
      list_for_each(cchildren_list_head, &p->children){
        pc = list_entry(cchildren_list_head, struct task_struct, sibling);
        printk(KBUILD_MODNAME ": - - %s [%d] \n", pc->comm, pc->pid);
      }
    }
  }
  rcu_read_unlock(); //~ read_unlock(&tasklist_lock);

  // NOTE: here p == callmodule_infoB->task !!
  printk(KBUILD_MODNAME ": Trying to walk page table; addr task 0x%X ->mm ->start_code: 0x%08lX ->end_code: 0x%08lX \n", (unsigned int) callmodule_infoB->task, callmodule_infoB->task->mm->start_code, callmodule_infoB->task->mm->end_code);
  //
  for (i=0; i<NUM_USER_ADDRS; i++) {
    taddr = callmodule_useraddrs[i];
    if (taddr != 0) {
      offset = taddr - callmodule_infoB->task->mm->start_code;
      walk_page_table(taddr, callmodule_infoB->task);
      if (callmodule_infoB->last_page_physaddr != 0ULL) {
        callmodule_physaddrs[i] = callmodule_infoB->last_page_physaddr+offset;
      }
      printk(": (0x%08lx ->) 0x%08llx ", callmodule_useraddrs[i], callmodule_physaddrs[i]);

      if (callmodule_physaddrs[i] != 0) {
        #if TRY_USE_KPROBES // can't use this here (BUG: scheduling while atomic, if probe inserts)
        //~ sprintf(trcmd, "p:myprobe 0x%08llx", callmodule_infoB->last_page_physaddr+offset);
        // try symbol for c10bcf60 - tracing_on? seems to trigger, but w/ fatal bug (see below)
        sprintf(trcmd, "p:myprobe 0x%08llx", (unsigned long long)0xc10bcf60);
        ret = traceprobe_command(trcmd, ptr_create_trace_probe); //create_trace_probe);
        printk("%s -- ret: %d\n", trcmd, ret);
        // try find probe and enable it (compiles, but untested - will likely fail due BUG above):
        tp = ptr_find_probe_event("myprobe", KPROBE_EVENT_SYSTEM);
        if (tp != NULL) probe_event_enable(&tp->call);
        #endif //TRY_USE_KPROBES
      } // end if (callmodule_physaddrs[i] != 0)

      hw_breakpoint_init(&attrs[i]);
      attrs[i].bp_len = sizeof(long); //HW_BREAKPOINT_LEN_1;
      attrs[i].bp_type = HW_BREAKPOINT_X ;
      attrs[i].bp_addr = taddr;
      callmodule_hbps[i] = register_user_hw_breakpoint(&attrs[i], (perf_overflow_handler_t)sample_hbp_handler, p);
      printk(KBUILD_MODNAME ": 0x%08lx id [%llu]\n", taddr, callmodule_hbps[i]->id); //
      if (IS_ERR((void __force *)callmodule_hbps[i])) {
        int ret = PTR_ERR((void __force *)callmodule_hbps[i]);
        printk(KBUILD_MODNAME ": Breakpoint registration failed (%d)\n", ret);
        return ret;
      } // end if (IS_ERR
    } // end if (taddr != 0)
  } // end for

  kill_pid(find_vpid(callmodule_pid), SIGCONT, 1); // resume/continue/restart task

  state_str = (p->state==-1)?"unrunnable":((p->state==0)?"runnable":"stopped");
  printk(KBUILD_MODNAME ": cont pid task a: %p c: %s p: [%d] s: %s\n",
    p, p->comm, p->pid, state_str);

  return 0;
}

static void __exit callmodule_exit(void)
{
  int i;
  tracing_off(); //corresponds to the user space /sys/kernel/debug/tracing/tracing_on file
  for (i=0; i<NUM_USER_ADDRS; i++) {
    unregister_hw_breakpoint(callmodule_hbps[i]);
  }
  printk(KBUILD_MODNAME ": < exit\n");
}

module_init(callmodule_init);
module_exit(callmodule_exit);
