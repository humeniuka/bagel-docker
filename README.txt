Docker Image with BAGEL
-----------------------

~
  docker build --tag quack-quack/bagel:1.2.0 .

~
  docker run --rm -it quack-quack/bagel:1.2.0


Compute the Hartree-Fock energy of the HF molecule as a test case:

~bash
  docker run -w /tests -i -t quack-quack/bagel:1.2.0 BAGEL hf_svp_hf.json
~
