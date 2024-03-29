c----------------------------------------------------------------------- 
c 
c     This file is part of the Test Set for IVP solvers 
c     http://www.dm.uniba.it/~testset/ 
c 
c        (ODE only) VODE driver 
c 
c     DISCLAIMER: see 
c     http://www.dm.uniba.it/~testset/disclaimer.php
c 
c     The most recent version of this source file can be found at 
c     http://www.dm.uniba.it/~testset/src/drivers/voded.f 
c 
c     This is revision 
c     $Id: voded.f,v 1.6 2006/10/02 10:19:09 testset Exp $ 
c 
c----------------------------------------------------------------------- 
 
      program voded 
 
      integer maxneq 
      parameter (maxneq=400) 
      integer lrw, liw 
      parameter(lrw=22+9*maxneq+2*maxneq**2,liw=30+maxneq) 
 
      integer neqn,ndisc,mljac,mujac,mlmas,mumas,ind(maxneq), 
     +        itol,itask,istate,iopt,iwork(liw),mf,ipar(2),itotal(22) 
 
      double precision y(maxneq),yprime(maxneq),t(0:100), 
     +                 h0,rtol(maxneq),atol(maxneq), 
     +                 rwork(lrw),rpar(1) 
      logical numjac,nummas,consis,tolvec 
 
      double precision yref(maxneq) 
      external odef, odejac 
      character fullnm*40, problm*8, type*3 
      character driver*8, solver*8 
      parameter (driver = 'voded', solver='VODE') 
 
      double precision solmax 
      real gettim, timtim, cputim 
      external gettim 
      double precision scd, mescd 
 
 
      character  fileout*140,  filepath*100 
      character formatout*30,namefile*100 
      logical printsolout, solref, printout 
      integer nindsol, indsol(maxneq) 
 
 
      integer i 
 
 
      iopt = 1 
      do 10 i = 5,10 
         iwork(i) = 0 
         rwork(i) = 0d0 
   10 continue 
c 
c     VODE is allowed to make more f-evalutations: 
c 
      iwork(6) = 1000000 
 
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
         print *, 'VODED: ERROR: ', 
     +            'VODE can not solve IDEs' 
         stop 
      elseif (type.eq.'DAE') then 
         print *, 'VODED: ERROR: ', 
     +            'VODE can not solve DAEs' 
         stop 
      elseif (type.ne.'ODE') then 
         print *, 'VODED: ERROR: ', 
     +            'unknown Test Set problem type', type 
         stop 
      endif 
 
      if (mljac.eq.neqn) then 
         mf = 22 
      else 
         mf = 25 
         iwork(1) = mljac 
         iwork(2) = mujac 
      endif 
      if (.not. numjac) mf = mf - 1 
 
c----------------------------------------------------------------------- 
c     get the initial values 
c----------------------------------------------------------------------- 
 
      call init(neqn,t(0),y,yprime,consis) 
 
c----------------------------------------------------------------------- 
c     read the tolerances 
c----------------------------------------------------------------------- 
 
      call getinp(driver,problm,solver,fullnm, 
     +            tolvec,rtol,atol,h0,solmax) 
 
      call settolerances(neqn,rtol,atol,tolvec) 
 
      if (tolvec) then 
         itol = 2 
      else 
         itol = 1 
      endif 
 
      call  setoutput(neqn,solref,printsolout, 
     +                        nindsol,indsol) 
 
c 
c     for an accurate solution in the Test Set endpoint 
c     (the scd-value) we do not want the solution to be interpolated 
c     so not only for discontinuities (as it should) but also 
c     for the Test Set endpoint (see also rwork(1)): 
c 
 
      if (printsolout) then 
 
          itask = 5 
              
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
 
      else 
 
          itask = 4 
 
      end if 
 
      if (printsolout) then 
        write(formatout,'(a,i5,a)') '(e23.15,',nindsol,'(e23.15))' 
      end if 
c----------------------------------------------------------------------- 
c     call of the subroutine VODE 
c----------------------------------------------------------------------- 
 
      do 20 i=1,22 
         itotal(i) = 0 
   20 continue 
 
      timtim = gettim() 
      timtim = gettim() - timtim 
 
 
      if (printsolout) then  
          write(90,formatout)  
     +       t(0), (y(indsol(it)),it=1,nindsol) 
      end if 
 
      cputim = gettim() 
 
      do 70 i=0,ndisc 
 
         rwork(1) = t(i+1) 
 
c        (re)-initialize 
 
         istate = 1 
 
         if (printsolout) then  
           do 80 while (t(i).lt.t(i+1)) 
             call dvode(odef,neqn,y,t(i),t(i+1),itol,rtol,atol,itask, 
     +                  istate,iopt,rwork,lrw,iwork,liw,odejac,mf, 
     +                  rpar,ipar) 
 
             if (istate.lt.0) then 
               print *, 'VODED: ERROR: ', 
     +                  'VODE returned ISTATE = ', istate 
               stop 
             endif 
             write(90,formatout)  
     +         t(i), (y(indsol(it)),it=1,nindsol) 
             istate = 2 
   80      continue 
         else 
             call dvode(odef,neqn,y,t(i),t(i+1),itol,rtol,atol,itask, 
     +                  istate,iopt,rwork,lrw,iwork,liw,odejac,mf, 
     +                  rpar,ipar) 
 
             if (istate.lt.0) then 
               print *, 'VODED: ERROR: ', 
     +                  'VODE returned ISTATE = ', istate 
               stop 
             endif 
         end if 
 
         itotal(11) = itotal(11) + iwork(11) 
         itotal(12) = itotal(12) + iwork(12) 
         itotal(13) = itotal(13) + iwork(13) 
         itotal(19) = itotal(19) + iwork(19) 
         itotal(20) = itotal(20) + iwork(20) 
         itotal(21) = itotal(21) + iwork(21) 
         itotal(22) = itotal(22) + iwork(22) 
 
   70 continue 
 
      cputim = gettim() - cputim - timtim 
 
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
     +   itotal,cputim,scd,mescd 
     +) 
      end 
 
C======================================================================= 
C     `Test Set for IVP Solvers' ODE wrappers for VODE 
C======================================================================= 
c 
c     since in VODE the format of the subroutine containing the 
c     derivative function and its Jacobian differ from the format in the 
c     testset, we transform them 
c 
c----------------------------------------------------------------------- 
      subroutine odef(neq,t,y,ydot,rpar,ipar) 
      integer neq,ipar 
      double precision t,y(neq),ydot(neq),rpar 
      integer ierr 
      ierr = 0 
      call feval(neq,t,y,y,ydot,ierr,rpar,ipar) 
      if (ierr.ne.0) then 
         print *, 'VODED: ERROR: ', 
     +            'VODE can not handle FEVAL IERR' 
         stop 
      endif 
      return 
      end 
 
      subroutine odejac(neq,t,y,ml,mu,pd,nrowpd,rpar,ipar) 
      integer neq,ml,mu,nrowpd,ipar 
      double precision t,y(neq),pd(nrowpd,neq),rpar 
      integer ierr 
      ierr = 0 
      call jeval(nrowpd,neq,t,y,y,pd,ierr,rpar,ipar) 
      if (ierr.ne.0) then 
         print *, 'VODED: ERROR: ', 
     +            'VODE can not handle JEVAL IERR' 
         stop 
      endif 
      return 
      end 
