.text
.globl switch_context
.type switch_context,@function
switch_context:
  lea 8(%rsp), %rax
  mov %rax, 0(%rdi)        
  mov (%rsp), %rax
  mov %rax, 8(%rdi)        
  mov %rbx, 16(%rdi)
  mov %rbp, 24(%rdi)
  mov %r12, 32(%rdi)
  mov %r13, 40(%rdi)
  mov %r14, 48(%rdi)
  mov %r15, 56(%rdi)

  mov 16(%rsi), %rbx
  mov 24(%rsi), %rbp
  mov 32(%rsi), %r12
  mov 40(%rsi), %r13
  mov 48(%rsi), %r14
  mov 56(%rsi), %r15
  mov 0(%rsi), %rsp        

  mov 8(%rsi), %rax        
  mov 64(%rsi), %rdi       
  jmp *%rax
