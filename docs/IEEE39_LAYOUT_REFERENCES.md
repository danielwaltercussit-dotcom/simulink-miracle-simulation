# IEEE 39-Bus Layout References

This note records the references used for the project layout convention.

## References Consulted

- ICSEG / University of Illinois describes the IEEE 39-bus system as the
  10-machine New England Power System and notes that it has 10 generators and
  46 lines.
- ICSEG attributes the original IEEE 39-bus system paper to T. Athay,
  R. Podmore, and S. Virmani, "A Practical Method for the Direct Analysis of
  Transient Stability," IEEE Transactions on Power Apparatus and Systems,
  PAS-98, no. 2, March/April 1979, pp. 573-584.
- A 2021 Energies paper uses the IEEE New England 39-bus test case as a
  MATLAB/Simulink transient stability benchmark and shows a single-line diagram
  of the test case. It describes the model as containing 10 synchronous
  machines, transmission lines, three-phase transformers, loads, AVR, PSS, and
  turbine governor controls.
- The user-provided reference image follows the same common single-line
  placement: G30 and G37 on the top-left area, G38 on the right, G31-G35 along
  the lower area, G36 on the right-middle, and G39 on the left.

## Layout Convention Adopted

Top-level generated models should use a canonical single-line layout for
standard benchmark cases when such a layout is known. For IEEE 39:

- Place bus nodes according to the standard New England one-line diagram, not
  purely by bus number and not by unconstrained force-directed layout.
- Place branch blocks near the geometric midpoint of the two connected buses.
- Place generator or converter blocks adjacent to their connected generator bus
  in the conventional side of the one-line diagram.
- Keep semantic coloring: buses blue, branches white/gray, SG green, DFIG
  orange, configuration yellow.
- Preserve trace metadata independently from visual placement.
