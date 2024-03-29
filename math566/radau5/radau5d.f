c----------------------------------------------------------------------- 
c 
c     This file is part of the Test Set for IVP solvers 
c     http://www.dm.uniba.it/~testset/ 
c 
c        generic RADAU5 driver 
c 
c     DISCLAIMER: see 
c     http://www.dm.uniba.it/~testset/disclaimer.php 
c 
c     The most recent version of this source file can be found at 
c     http://www.dm.uniba.it/~testset/src/drivers/radau5d.f 
c 
c     This is revision 
c     $Id: radau5d.f,v 1.8 2006/10/02 10:19:09 testset Exp $ 
c 
c----------------------------------------------------------------------- 
 
      program radaud 
 
      integer md 
      parameter (md=400) 
      integer lwork, liwork 
      parameter (lwork=4*md*md+12*md+20,liwork=3*md+20) 
 
      integer neqn,ndisc,mljac,mujac,mlmas,mumas,ind(md), 
     +        iwork(20+4*md),ipar(md+1),idid 
      double precision y(md),dy(md),t(0:100), 
     +                 h0,rtol(md),atol(md), 
     +                 work(lwork),rpar(1) 
      logical numjac,nummas,consis,tolvec 
 
      integer itol,ijac,imas,iout 
      double precision h 
 
      double precision yref(md) 
      character fullnm*40, problm*8, type*3 
      character driver*8, solver*8 
      parameter (driver = 'radau5d', solver='RADAU5') 
      external odef,odejac,odemas 
      external daef,daejac,daemas 
      external solout 
 
      double precision solmax 
      real gettim, timtim, cputim 
      external gettim 
      double precision scd, mescd 
 
      character  fileout*140,  filepath*100 
      character formatout*30, namefile*100 
      logical printsolout, solref, printout 
      integer nindsol, indsol(md) 
 
      integer i,j,icount(14:20) 
 
      do 10 i=1,20 
         iwork(i) = 0 
         work(i)  = 0d0 
   10 continue 
c 
c     NMAX , the maximal number of steps 
c 
      iwork(2) = 1000000 
      iout = 0 
 
c----------------------------------------------------------------------- 
c     check the problem definition interface date 
c----------------------------------------------------------------------- 
 
      call chkdat(driver,solver,20060828) 
 
c----------------------------------------------------------------------- 
c     get the problem dependent parameters 
c----------------------------------------------------------------------- 
 
      call prob(fullnm,problm,type, 
     +          neqn,ndisc,t, 
     +          numjac,mljac,mujac, 
     +          nummas,mlmas,mumas, 
     +          ind) 
      if (type.eq.'IDE') then 
         print *, 'RADAU5D: ERROR: ', 
     +            'RADAU5 can not solve IDEs' 
         stop 
      elseif (type.eq.'ODE') then 
         imas = 0 
      elseif (type.eq.'DAE') then 
         imas = 1 
         do 20 i=1,neqn 
            if (ind(i).eq.0 .or. ind(i).eq.1) then 
               iwork(5)=iwork(5)+1 
            elseif (ind(i).eq.2) then 
               iwork(6)=iwork(6)+1 
            elseif (ind(i).eq.3) then 
               iwork(7)=iwork(7)+1 
            else 
               print *, 'RADAU5D: ERROR: ', 
     +         'RADAU5 can not solve index ', ind(i), ' problems' 
               stop 
            endif 
   20    continue 
         do 30 i=2,neqn 
            if (ind(i).lt.ind(i-1)) then 
               print *, 'RADAU5D: ERROR: ', 
     +         'RADAU5 requires the index 1,2,3 variables ', 
     +         'to appear in this order' 
               stop 
            endif 
   30    continue 
      else 
         print *, 'RADAU5D: ERROR: ', 
     +            'unknown Test Set problem type', type 
         stop 
      endif 
      if (numjac) then 
         ijac = 0 
      else 
         ijac = 1 
      endif 
 
c----------------------------------------------------------------------- 
c     get the initial values 
c----------------------------------------------------------------------- 
 
      call init(neqn,t(0),y,dy,consis) 
 
c----------------------------------------------------------------------- 
c     read the tolerances and initial stepsize 
c----------------------------------------------------------------------- 
 
      call getinp(driver,problm,solver,fullnm, 
     +            tolvec,rtol,atol,h0,solmax) 
 
      call settolerances(neqn,rtol,atol,tolvec) 
 
      if (tolvec) then 
         itol = 1 
      else 
         itol = 0 
      endif 
 
      call  setoutput(neqn,solref,printsolout,nindsol,indsol) 
 
      if (printsolout) then 
 
          iout = 1 
          ipar(1) = nindsol 
          do i=1,nindsol 
            ipar(i+1) = indsol(i) 
          end do 
 
          call getarg(1,filepath) 
          call getarg(2,namefile) 
           
          if (lnblnk(namefile) .gt. 0) then 
            write(fileout,'(a,a,a,a)') filepath(1:lnblnk(filepath)), namefile(1:lnblnk(namefile)), solver(1:lnblnk(solver)),'.txt' 
                 
             open(UNIT=90,FILE=fileout) 
  
             call mfileout(namefile,solver,filepath,nindsol,indsol) 
   
          else 
            write(fileout,'(a,a,a,a)') filepath(1:lnblnk(filepath)), problm(1:lnblnk(problm)), solver(1:lnblnk(solver)),'.txt' 
                 
             open(UNIT=90,FILE=fileout) 
  
             call mfileout(problm,solver,filepath,nindsol,indsol) 
          end if   
     
      end if 
 
c----------------------------------------------------------------------- 
c     call of the subroutine RADAU5 
c----------------------------------------------------------------------- 
 
      do 40 j=14,20 
         icount(j) = 0 
   40 continue 
 
 
      if (printsolout) then 
c the initial condition is printed in the oputput file 
        write(formatout,'(a,i5,a)') '(e23.15,',nindsol,'(e23.15))' 
        write(90,formatout)  
     +       t(0), (y(indsol(it)),it=1,nindsol) 
      end if 
 
      timtim = gettim() 
      timtim = gettim() - timtim 
 
      cputim = gettim() 
 
 
      do 60 i=0,ndisc 
 
         h = h0 
 
         if (type.eq.'ODE') then 
            call radau5(neqn,odef,t(i),y,t(i+1),h, 
     +                  rtol,atol,itol, 
     +                  odejac ,ijac,mljac,mujac, 
     +                  odemas ,imas,mlmas,mumas, 
     +                  solout,iout, 
     +                  work,lwork,iwork,liwork,rpar,ipar,idid) 
         elseif (type.eq.'DAE') then 
            call radau5(neqn,daef,t(i),y,t(i+1),h, 
     +                  rtol,atol,itol, 
     +                  daejac ,ijac,mljac,mujac, 
     +                  daemas ,imas,mlmas,mumas, 
     +                  solout,iout, 
     +                  work,lwork,iwork,liwork,rpar,ipar,idid) 
         endif 
 
         if (idid.ne.1) then 
            print *, 'RADAU5D: ERROR: ', 
     +               'RADAU5 returned IDID = ', idid 
            stop 
         endif 
 
         do 50 j=14,20 
            icount(j) = icount(j) + iwork(j) 
   50    continue 
 
   60 continue 
 
      cputim = gettim() - cputim - timtim 
 
      do 70 j=14,20 
         iwork(j) = icount(j) 
   70 continue 
 
c----------------------------------------------------------------------- 
c     print numerical solution in endpoint and integration statistics 
c----------------------------------------------------------------------- 
 
      
      printout = .true. 
      if (solref) then  
        call solut(neqn,t(ndisc+1),yref) 
        call getscd(mescd,scd,neqn,yref,y,problm,tolvec,atol,rtol, 
     +               printout) 
      else 
        call printsol(neqn,y,problm) 
      end if 
 
      call report( 
     +   driver,problm,solver, 
     +   rtol,atol,h0,solmax, 
     +   iwork,cputim,scd,mescd 
     +) 
 
      if (printsolout) then 
         close(90) 
      end if 
 
      end 
 
      subroutine solout(nr,xold,x,y,cont,lrc,n,rpar,ipar,irtrn) 
      integer nr,lrc,n,ipar(*),irtrn 
      double precision xold,x,y(n),cont(lrc),rpar(*) 
 
      integer i 
      character formatout*30 
 
      nindsol = ipar(1) 
 
      write(formatout,'(a,i5,a)') '(e23.15,',nindsol,'(e23.15))' 
 
      write(90,formatout)  
     +      x, (y(ipar(i+1)),i=1,nindsol) 
 
 
       
      irtrn = 0 
      return 
      end 
 
C======================================================================= 
C     `Test Set for IVP Solvers' ODE wrappers for RADAU5 
C======================================================================= 
c 
c     since in RADAU5 the format of the subroutines for the 
c     function f and the Jacobian differ from the format 
c     in the testset, we transform them 
c 
c----------------------------------------------------------------------- 
      subroutine odef(n,x,y,f,rpar,ipar) 
      integer n,ipar(*) 
      double precision x,y(n),f(n),rpar(*) 
      integer ierr 
      ierr = 0 
      call feval(n,x,y,y,f,ierr,rpar,ipar) 
      if (ierr.ne.0) then 
         print *, 'RADAU5D: ERROR: ', 
     +            'RADAU5 can not handle FEVAL IERR' 
         stop 
      endif 
      return 
      end 
 
      subroutine odejac(n,x,y,dfy,ldfy,rpar,ipar) 
      integer ldfy,n,ipar(*) 
      double precision x,y(n),dfy(ldfy,n),rpar(*) 
      integer ierr 
      double precision dy 
      ierr = 0 
      call jeval(ldfy,n,x,y,dy,dfy,ierr,rpar,ipar) 
      if (ierr.ne.0) then 
         print *, 'RADAU5D: ERROR: ', 
     +            'RADAU5 can not handle JEVAL IERR' 
         stop 
      endif 
      return 
      end 
 
      subroutine odemas(n,am,lmas,rpar,ipar) 
      integer n,lmas,ipar(*) 
      double precision am(lmas,n),rpar(*) 
      return 
      end 
C======================================================================= 
C     `Test Set for IVP Solvers' DAE wrappers for RADAU5 
C======================================================================= 
c 
c     since in RADAU5 the format of the subroutines for the 
c     function f, the Jacobian and the Mass-matrix differ from the 
c     format in the testset, we transform them 
c 
c----------------------------------------------------------------------- 
      subroutine daef(n,x,y,f,rpar,ipar) 
      integer n,ipar(*) 
      double precision x,y(n),f(n),rpar(*) 
      integer ierr 
      ierr = 0 
      call feval(n,x,y,y,f,ierr,rpar,ipar) 
      if (ierr.ne.0) then 
         print *, 'RADAU5D: ERROR: ', 
     +            'RADAU5 can not handle FEVAL IERR' 
         stop 
      endif 
      return 
      end 
 
      subroutine daejac(n,x,y,dfy,ldfy,rpar,ipar) 
      integer ldfy,n,ipar(*) 
      double precision x,y(n),dfy(ldfy,n),rpar(*) 
      integer ierr 
      double precision dy 
      ierr = 0 
      call jeval(ldfy,n,x,y,dy,dfy,ierr,rpar,ipar) 
      if (ierr.ne.0) then 
         print *, 'RADAU5D: ERROR: ', 
     +            'RADAU5 can not handle JEVAL IERR' 
         stop 
      endif 
      return 
      end 
 
      subroutine daemas(n,am,lmas,rpar,ipar) 
      integer n,lmas,ipar(*) 
      double precision am(lmas,n),rpar(*) 
      integer ierr 
      double precision x,y,dy 
      ierr = 0 
      call meval(lmas,n,x,y,dy,am,ierr,rpar,ipar) 
      if (ierr.ne.0) then 
         print *, 'RADAU5D: ERROR: ', 
     +            'RADAU5 can not handle MEVAL IERR' 
         stop 
      endif 
      return 
      end 
