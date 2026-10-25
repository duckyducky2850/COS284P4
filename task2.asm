; rdi = dfa, rsi = input
;
; bool simulateDfa(DFA* dfa, const char* input)
;
; Reference C:
;
; bool simulateDfa(DFA* dfa, const char* input) {
;     int current   = dfa->startState;
;     Transition* t = dfa->transitions;
;     int m         = dfa->numTransitions;
;
;     for (const char* p = input; *p != '\0'; p++) {
;         int j;
;         for (j = 0; j < m; j++)
;             if (t[j].from == current && t[j].symbol == *p)
;                 break;
;         if (j == m) return false;            // no transition = reject
;         current = t[j].to;
;     }
;
;     return dfa->states[current].isAccepting;
; }



global simulateDfa

; ---- struct layouts (same as task1.asm; each file is assembled alone) ----
struc State
  .id           resd 1      ; offset 0
  .isAccepting  resb 1      ; offset 4
  alignb 4                  ; pad to 8
endstruc

struc Transition
  .from         resd 1      ; offset 0
  .to           resd 1      ; offset 4
  .symbol       resb 1      ; offset 8
  alignb 4                  ; pad to 12
endstruc

struc DFA
  .states         resq 1    ; offset 0
  .transitions    resq 1    ; offset 8
  .numStates      resd 1    ; offset 16
  .numTransitions resd 1    ; offset 20
  .startState     resd 1    ; offset 24
  alignb 8                  ; pad to 32
endstruc

section .text

; Leaf function: no calls, so only caller-saved registers are used
; and no prologue or stack alignment is needed.
;   rdi = dfa          rsi = p (input cursor)
;   r8d = current      r9  = transitions base
;   r10d = numTransitions
;   rdx = &t[j]        ecx = j        al = *p
simulateDfa:
  mov r8d, [rdi + DFA.startState]
  mov r9, [rdi + DFA.transitions]
  mov r10d, [rdi + DFA.numTransitions]

.charLoop:
  mov al, [rsi]             ; c = *p
  cmp al, 0
  je .endOfInput

  xor ecx, ecx              ; j = 0
  mov rdx, r9               ; rdx = &t[0]
.searchLoop:
  cmp ecx, r10d
  jge .reject               ; ran out of transitions
  cmp [rdx + Transition.from], r8d
  jne .next
  cmp [rdx + Transition.symbol], al   ; byte compare
  jne .next
  ; match
  mov r8d, [rdx + Transition.to]      ; current = t[j].to
  inc rsi                   ; p++
  jmp .charLoop
.next:
  add rdx, Transition_size  ; &t[j+1]
  inc ecx
  jmp .searchLoop

.endOfInput:
  mov rdx, [rdi + DFA.states]
  mov ecx, r8d
  imul rcx, rcx, State_size
  movzx eax, byte [rdx + rcx + State.isAccepting]
  ret

.reject:
  xor eax, eax              ; false
  ret
