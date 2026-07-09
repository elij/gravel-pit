# Gravel Pit

> [!WARNING]
> This repository is archived and no longer actively maintained. The code is evolved further in `macher-agent` [sandbox](https://github.com/elij/macher-agent/blob/main/macher-agent-sandbox.el)

Proof of concept using macroexpand-all and side-effect-free as the basis of a sandboxed elisp interpreter.

This is a bit different to other approaches like [elisp-sandbox](https://github.com/joelmccracken/elisp-sandbox) which is based around faster at execution rewriting approach.

This is a proving ground before upstreaming into [macher-agent](https://github.com/elij/macher-agent).

(Avoiding solutions based around containerisation/hypervisor and focusing on something more like Deno)

## TODO
- subset of side-effect-free to avoid access to privacy leaking functions
- approach to allowing safe-ish side effect functions like time and random
- later consider file system and network access

### Safe block
```elisp
(let ((safe-program
       '(progn

          (defun calculate-volume (width height depth)
            (* width height depth))
            
          ;; variable same name
          (let ((calculate-volume 999))
            (message (concat "Volume is: " 
                    (number-to-string (calculate-volume 5 10 2))))))))
                    
  (gravel-pit-run safe-program '(number-to-string message)))
```

### Unsafe block
```elisp
(let ((malicious-program
       '(insert-file-contents "/etc/passwd")))
       
  (condition-case err
      (gravel-pit-run malicious-program nil)
    (error (message "Execution halted: %S" err))))
```
