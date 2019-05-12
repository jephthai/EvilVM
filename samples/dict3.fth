0 !echo

\ This is an example of building and using a "dictionary" in EvilForth.
\ The implementation is via a binary search tree (BST).  This is not as
\ efficient as a more complex hash table, but does quite well at making
\ insertions and retrievals speedy, without the complexity of handling
\ collisions, etc.

\ Constructors for two types of elements in a list.  We allocate the
\ nodes in the dictionary, which does mean they cannot easily be
\ reclaimed.  

: node   here >r 0 , , , , r> ;
: leaf   0 0 rot node ;

\ offsets into a node structure that we can use to refer to each of the
\ components by name.  This makes code later on much more readable.

: >value ; 
: >data  cell + ;
: >right cell + cell + ;
: >left  cell + cell + cell + ;

\ A simple in-order traversal of the tree.  

: inorder
  dup 0= if 2drop return then
  2dup >left @ recurse
  2dup >data @ swap execute
       >right @ tail ;

\ Comparing a value against a node -- this hard-codes "2@" as an
\ "accessor" function for node keys.  In a more generalized solution, we
\ might make this configurable (or make it live with the definition of
\ the tree), in case we wanted to key our objects differently.

: node-cmp >r 2@ r> >data @ 2@ strcmp ;

\ Now we get to insertions.  This may appear a little odd, but it turns
\ out to be convenient to use three parameters to an insert.  We have
\ the new key, the branch pointer we just took, and the current node
\ for examination.  This allows us to insert the node when we reach a
\ leaf, instead of recursing expensively and handling the addition in
\ post. 

\ These two will turn a key and a node into a key, branch pointer, and
\ child node prior to recursion.

: go-left  dup >r >left r> >left @ ;
: go-right dup >r >right r> >right @ ;

: insert ( key branch node -- node )

  \ hit a leaf? make a new node, and grow the branch
  dup 0= if drop >r leaf dup r> ! return then

  \ ignore the branch we came from; compare and tail
  nip 2dup node-cmp
  dup equal = if drop nip return       then 
      less  = if      go-left  tail then
                      go-right tail     
;

\ When we search the tree, we recurse until we either find a matching
\ node, or fail.  We leave a pointer to the tree node that matched if
\ we are successul, which simplifies access to the node's data and
\ setting values.

: tree-get ( key tree -- node )
  dup 0= if nip return then
  2dup node-cmp
  dup equal = if drop nip return then
  dup less  = if drop >left @ tail then
      more  = if >right @ tail then
  2drop 0 ;

\ We encourage storing a pointer to a tree, so this wrapper makes the
\ interface consistent with that model.

: tree-get @ tree-get ;

: tree-set ( value key tree -- )
  dup @ insert >value ! ;


\ ------------------------------------------------------------------------
\ Demo / test code follows
\ ------------------------------------------------------------------------

\ We will define a pointer to a tree; it starts as an empty tree (NULL)
variable tree tree off

\ We will define keys as pointers to strings using this convenient parser
: name 
  create readline trim ( addr u )
  here 16 allot over here swap rot 2! here over allot swap move ;

\ Some of our most favorite fantasy heroes
name n1 Gandalf
name n2 Aragorn
name n3 Gimli
name n4 Legolas
name n5 Frodo
name f0 The Balrog
name n6 Sam
name n7 Merry
name n8 Pippin
name n9 Boromir
name e0 Smaug
name e1 Eowyn
name e2 Arwen

\ We'll build a dictionary mapping the character names to my own personal
\ wildly inaccurate estimate of their weights in pounds.
180 n1 tree tree-set
190 n2 tree tree-set
165 n3 tree tree-set
135 n4 tree tree-set
90  n5 tree tree-set
105 n6 tree tree-set
87  n7 tree tree-set
950 f0 tree tree-set
99  n8 tree tree-set
210 n9 tree tree-set
22150 e0 tree tree-set

\ Demonstrate an in-order traversal
{ ." Here are our heroes in alphabetical order:\n" }!
cr magenta { 2@ type space } tree @ inorder clear
cr cr

\ Check to see if an entry is in the dictionary
: test
  ." Is " dup 2@ blue type clear ."  in list? "
  tree tree-get if
    green ." Yes"
  else
    red ." No"
  then
  clear cr ;

\ Show the current weight of a character
: weighs 
  dup 2@ blue type clear ."  weighs " 
  tree tree-get
  dup 0= if 
    red ." UNKNOWN " clear ." pounds\n" 
  else
    >value @ cyan . clear ." pounds\n"
  then ;

\ Do some testing to see if it all works
e1 test
n3 test
e2 test
n7 test
cr
n1 weighs
n7 weighs
e0 weighs
n8 weighs
e1 weighs
n9 weighs

\ And if iterating through the contents of the dictionary is of any use,
\ here's an example of doing that...

cr
{ ." Actually, let's see all of them!\n\n" }!

{ weighs } tree @ inorder

cr
bye
