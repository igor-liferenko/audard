
min.exe:     file format elf32-i386


Disassembly of section .init:

08048324 <_init>:
 8048324:	55                   	push   %ebp
 8048325:	89 e5                	mov    %esp,%ebp
 8048327:	53                   	push   %ebx
 8048328:	83 ec 04             	sub    $0x4,%esp
 804832b:	e8 00 00 00 00       	call   8048330 <_init+0xc>
 8048330:	5b                   	pop    %ebx
 8048331:	81 c3 c4 1c 00 00    	add    $0x1cc4,%ebx
 8048337:	8b 93 f8 ff ff ff    	mov    -0x8(%ebx),%edx
 804833d:	85 d2                	test   %edx,%edx
 804833f:	74 05                	je     8048346 <_init+0x22>
 8048341:	e8 aa 00 00 00       	call   80483f0 <__gmon_start__>
 8048346:	e8 55 01 00 00       	call   80484a0 <frame_dummy>
 804834b:	e8 50 02 00 00       	call   80485a0 <__do_global_ctors_aux>
 8048350:	58                   	pop    %eax
 8048351:	5b                   	pop    %ebx
 8048352:	c9                   	leave  
 8048353:	c3                   	ret    

Disassembly of section .plt:

08048354 <_mcleanup@plt-0x10>:
 8048354:	ff 35 f8 9f 04 08    	pushl  0x8049ff8
 804835a:	ff 25 fc 9f 04 08    	jmp    *0x8049ffc
 8048360:	00 00                	add    %al,(%eax)
	...

08048364 <_mcleanup@plt>:
 8048364:	ff 25 00 a0 04 08    	jmp    *0x804a000
 804836a:	68 00 00 00 00       	push   $0x0
 804836f:	e9 e0 ff ff ff       	jmp    8048354 <_init+0x30>

08048374 <__cxa_atexit@plt>:
 8048374:	ff 25 04 a0 04 08    	jmp    *0x804a004
 804837a:	68 08 00 00 00       	push   $0x8
 804837f:	e9 d0 ff ff ff       	jmp    8048354 <_init+0x30>

08048384 <__libc_start_main@plt>:
 8048384:	ff 25 08 a0 04 08    	jmp    *0x804a008
 804838a:	68 10 00 00 00       	push   $0x10
 804838f:	e9 c0 ff ff ff       	jmp    8048354 <_init+0x30>

08048394 <__monstartup@plt>:
 8048394:	ff 25 0c a0 04 08    	jmp    *0x804a00c
 804839a:	68 18 00 00 00       	push   $0x18
 804839f:	e9 b0 ff ff ff       	jmp    8048354 <_init+0x30>

080483a4 <mcount@plt>:
 80483a4:	ff 25 10 a0 04 08    	jmp    *0x804a010
 80483aa:	68 20 00 00 00       	push   $0x20
 80483af:	e9 a0 ff ff ff       	jmp    8048354 <_init+0x30>

Disassembly of section .text:

080483c0 <_start>:
 80483c0:	31 ed                	xor    %ebp,%ebp
 80483c2:	5e                   	pop    %esi
 80483c3:	89 e1                	mov    %esp,%ecx
 80483c5:	83 e4 f0             	and    $0xfffffff0,%esp
 80483c8:	50                   	push   %eax
 80483c9:	54                   	push   %esp
 80483ca:	52                   	push   %edx
 80483cb:	68 50 85 04 08       	push   $0x8048550
 80483d0:	68 f0 84 04 08       	push   $0x80484f0
 80483d5:	51                   	push   %ecx
 80483d6:	56                   	push   %esi
 80483d7:	68 c4 84 04 08       	push   $0x80484c4
 80483dc:	e8 a3 ff ff ff       	call   8048384 <__libc_start_main@plt>
 80483e1:	f4                   	hlt    
 80483e2:	90                   	nop
 80483e3:	90                   	nop
 80483e4:	90                   	nop
 80483e5:	90                   	nop
 80483e6:	90                   	nop
 80483e7:	90                   	nop
 80483e8:	90                   	nop
 80483e9:	90                   	nop
 80483ea:	90                   	nop
 80483eb:	90                   	nop
 80483ec:	90                   	nop
 80483ed:	90                   	nop
 80483ee:	90                   	nop
 80483ef:	90                   	nop

080483f0 <__gmon_start__>:
 80483f0:	55                   	push   %ebp
 80483f1:	89 e5                	mov    %esp,%ebp
 80483f3:	83 ec 18             	sub    $0x18,%esp
 80483f6:	a1 1c a0 04 08       	mov    0x804a01c,%eax
 80483fb:	85 c0                	test   %eax,%eax
 80483fd:	74 09                	je     8048408 <__gmon_start__+0x18>
 80483ff:	c9                   	leave  
 8048400:	c3                   	ret    
 8048401:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
 8048408:	c7 44 24 04 e8 85 04 	movl   $0x80485e8,0x4(%esp)
 804840f:	08 
 8048410:	c7 04 24 c0 83 04 08 	movl   $0x80483c0,(%esp)
 8048417:	c7 05 1c a0 04 08 01 	movl   $0x1,0x804a01c
 804841e:	00 00 00 
 8048421:	e8 6e ff ff ff       	call   8048394 <__monstartup@plt>
 8048426:	c7 04 24 64 83 04 08 	movl   $0x8048364,(%esp)
 804842d:	e8 2e 01 00 00       	call   8048560 <atexit>
 8048432:	c9                   	leave  
 8048433:	c3                   	ret    
 8048434:	90                   	nop
 8048435:	90                   	nop
 8048436:	90                   	nop
 8048437:	90                   	nop
 8048438:	90                   	nop
 8048439:	90                   	nop
 804843a:	90                   	nop
 804843b:	90                   	nop
 804843c:	90                   	nop
 804843d:	90                   	nop
 804843e:	90                   	nop
 804843f:	90                   	nop

08048440 <__do_global_dtors_aux>:
 8048440:	55                   	push   %ebp
 8048441:	89 e5                	mov    %esp,%ebp
 8048443:	53                   	push   %ebx
 8048444:	83 ec 04             	sub    $0x4,%esp
 8048447:	80 3d 20 a0 04 08 00 	cmpb   $0x0,0x804a020
 804844e:	75 3f                	jne    804848f <__do_global_dtors_aux+0x4f>
 8048450:	a1 24 a0 04 08       	mov    0x804a024,%eax
 8048455:	bb 1c 9f 04 08       	mov    $0x8049f1c,%ebx
 804845a:	81 eb 18 9f 04 08    	sub    $0x8049f18,%ebx
 8048460:	c1 fb 02             	sar    $0x2,%ebx
 8048463:	83 eb 01             	sub    $0x1,%ebx
 8048466:	39 d8                	cmp    %ebx,%eax
 8048468:	73 1e                	jae    8048488 <__do_global_dtors_aux+0x48>
 804846a:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
 8048470:	83 c0 01             	add    $0x1,%eax
 8048473:	a3 24 a0 04 08       	mov    %eax,0x804a024
 8048478:	ff 14 85 18 9f 04 08 	call   *0x8049f18(,%eax,4)
 804847f:	a1 24 a0 04 08       	mov    0x804a024,%eax
 8048484:	39 d8                	cmp    %ebx,%eax
 8048486:	72 e8                	jb     8048470 <__do_global_dtors_aux+0x30>
 8048488:	c6 05 20 a0 04 08 01 	movb   $0x1,0x804a020
 804848f:	83 c4 04             	add    $0x4,%esp
 8048492:	5b                   	pop    %ebx
 8048493:	5d                   	pop    %ebp
 8048494:	c3                   	ret    
 8048495:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
 8048499:	8d bc 27 00 00 00 00 	lea    0x0(%edi,%eiz,1),%edi

080484a0 <frame_dummy>:
 80484a0:	55                   	push   %ebp
 80484a1:	89 e5                	mov    %esp,%ebp
 80484a3:	83 ec 18             	sub    $0x18,%esp
 80484a6:	a1 20 9f 04 08       	mov    0x8049f20,%eax
 80484ab:	85 c0                	test   %eax,%eax
 80484ad:	74 12                	je     80484c1 <frame_dummy+0x21>
 80484af:	b8 00 00 00 00       	mov    $0x0,%eax
 80484b4:	85 c0                	test   %eax,%eax
 80484b6:	74 09                	je     80484c1 <frame_dummy+0x21>
 80484b8:	c7 04 24 20 9f 04 08 	movl   $0x8049f20,(%esp)
 80484bf:	ff d0                	call   *%eax
 80484c1:	c9                   	leave  
 80484c2:	c3                   	ret    
 80484c3:	90                   	nop

080484c4 <main>:

int main(void) {
 80484c4:	55                   	push   %ebp
 80484c5:	89 e5                	mov    %esp,%ebp
 80484c7:	83 ec 10             	sub    $0x10,%esp
 80484ca:	e8 d5 fe ff ff       	call   80483a4 <mcount@plt>
  int a = 2;
 80484cf:	c7 45 fc 02 00 00 00 	movl   $0x2,-0x4(%ebp)
  int b = 3;
 80484d6:	c7 45 f8 03 00 00 00 	movl   $0x3,-0x8(%ebp)
  int c;

  c = a + b;
 80484dd:	8b 45 f8             	mov    -0x8(%ebp),%eax
 80484e0:	8b 55 fc             	mov    -0x4(%ebp),%edx
 80484e3:	8d 04 02             	lea    (%edx,%eax,1),%eax
 80484e6:	89 45 f4             	mov    %eax,-0xc(%ebp)
  return c;
 80484e9:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
 80484ec:	c9                   	leave  
 80484ed:	c3                   	ret    
 80484ee:	90                   	nop
 80484ef:	90                   	nop

080484f0 <__libc_csu_init>:
 80484f0:	55                   	push   %ebp
 80484f1:	89 e5                	mov    %esp,%ebp
 80484f3:	57                   	push   %edi
 80484f4:	56                   	push   %esi
 80484f5:	53                   	push   %ebx
 80484f6:	e8 5a 00 00 00       	call   8048555 <__i686.get_pc_thunk.bx>
 80484fb:	81 c3 f9 1a 00 00    	add    $0x1af9,%ebx
 8048501:	83 ec 1c             	sub    $0x1c,%esp
 8048504:	e8 1b fe ff ff       	call   8048324 <_init>
 8048509:	8d bb 1c ff ff ff    	lea    -0xe4(%ebx),%edi
 804850f:	8d 83 1c ff ff ff    	lea    -0xe4(%ebx),%eax
 8048515:	29 c7                	sub    %eax,%edi
 8048517:	c1 ff 02             	sar    $0x2,%edi
 804851a:	85 ff                	test   %edi,%edi
 804851c:	74 24                	je     8048542 <__libc_csu_init+0x52>
 804851e:	31 f6                	xor    %esi,%esi
 8048520:	8b 45 10             	mov    0x10(%ebp),%eax
 8048523:	89 44 24 08          	mov    %eax,0x8(%esp)
 8048527:	8b 45 0c             	mov    0xc(%ebp),%eax
 804852a:	89 44 24 04          	mov    %eax,0x4(%esp)
 804852e:	8b 45 08             	mov    0x8(%ebp),%eax
 8048531:	89 04 24             	mov    %eax,(%esp)
 8048534:	ff 94 b3 1c ff ff ff 	call   *-0xe4(%ebx,%esi,4)
 804853b:	83 c6 01             	add    $0x1,%esi
 804853e:	39 fe                	cmp    %edi,%esi
 8048540:	72 de                	jb     8048520 <__libc_csu_init+0x30>
 8048542:	83 c4 1c             	add    $0x1c,%esp
 8048545:	5b                   	pop    %ebx
 8048546:	5e                   	pop    %esi
 8048547:	5f                   	pop    %edi
 8048548:	5d                   	pop    %ebp
 8048549:	c3                   	ret    
 804854a:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi

08048550 <__libc_csu_fini>:
 8048550:	55                   	push   %ebp
 8048551:	89 e5                	mov    %esp,%ebp
 8048553:	5d                   	pop    %ebp
 8048554:	c3                   	ret    

08048555 <__i686.get_pc_thunk.bx>:
 8048555:	8b 1c 24             	mov    (%esp),%ebx
 8048558:	c3                   	ret    
 8048559:	90                   	nop
 804855a:	90                   	nop
 804855b:	90                   	nop
 804855c:	90                   	nop
 804855d:	90                   	nop
 804855e:	90                   	nop
 804855f:	90                   	nop

08048560 <atexit>:
 8048560:	55                   	push   %ebp
 8048561:	89 e5                	mov    %esp,%ebp
 8048563:	53                   	push   %ebx
 8048564:	e8 ec ff ff ff       	call   8048555 <__i686.get_pc_thunk.bx>
 8048569:	81 c3 8b 1a 00 00    	add    $0x1a8b,%ebx
 804856f:	83 ec 0c             	sub    $0xc,%esp
 8048572:	8b 83 fc ff ff ff    	mov    -0x4(%ebx),%eax
 8048578:	85 c0                	test   %eax,%eax
 804857a:	74 1f                	je     804859b <atexit+0x3b>
 804857c:	8b 00                	mov    (%eax),%eax
 804857e:	89 44 24 08          	mov    %eax,0x8(%esp)
 8048582:	8b 45 08             	mov    0x8(%ebp),%eax
 8048585:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
 804858c:	00 
 804858d:	89 04 24             	mov    %eax,(%esp)
 8048590:	e8 df fd ff ff       	call   8048374 <__cxa_atexit@plt>
 8048595:	83 c4 0c             	add    $0xc,%esp
 8048598:	5b                   	pop    %ebx
 8048599:	5d                   	pop    %ebp
 804859a:	c3                   	ret    
 804859b:	31 c0                	xor    %eax,%eax
 804859d:	eb df                	jmp    804857e <atexit+0x1e>
 804859f:	90                   	nop

080485a0 <__do_global_ctors_aux>:
 80485a0:	55                   	push   %ebp
 80485a1:	89 e5                	mov    %esp,%ebp
 80485a3:	53                   	push   %ebx
 80485a4:	83 ec 04             	sub    $0x4,%esp
 80485a7:	a1 10 9f 04 08       	mov    0x8049f10,%eax
 80485ac:	83 f8 ff             	cmp    $0xffffffff,%eax
 80485af:	74 13                	je     80485c4 <__do_global_ctors_aux+0x24>
 80485b1:	bb 10 9f 04 08       	mov    $0x8049f10,%ebx
 80485b6:	66 90                	xchg   %ax,%ax
 80485b8:	83 eb 04             	sub    $0x4,%ebx
 80485bb:	ff d0                	call   *%eax
 80485bd:	8b 03                	mov    (%ebx),%eax
 80485bf:	83 f8 ff             	cmp    $0xffffffff,%eax
 80485c2:	75 f4                	jne    80485b8 <__do_global_ctors_aux+0x18>
 80485c4:	83 c4 04             	add    $0x4,%esp
 80485c7:	5b                   	pop    %ebx
 80485c8:	5d                   	pop    %ebp
 80485c9:	c3                   	ret    
 80485ca:	90                   	nop
 80485cb:	90                   	nop

Disassembly of section .fini:

080485cc <_fini>:
 80485cc:	55                   	push   %ebp
 80485cd:	89 e5                	mov    %esp,%ebp
 80485cf:	53                   	push   %ebx
 80485d0:	83 ec 04             	sub    $0x4,%esp
 80485d3:	e8 00 00 00 00       	call   80485d8 <_fini+0xc>
 80485d8:	5b                   	pop    %ebx
 80485d9:	81 c3 1c 1a 00 00    	add    $0x1a1c,%ebx
 80485df:	e8 5c fe ff ff       	call   8048440 <__do_global_dtors_aux>
 80485e4:	59                   	pop    %ecx
 80485e5:	5b                   	pop    %ebx
 80485e6:	c9                   	leave  
 80485e7:	c3                   	ret    
