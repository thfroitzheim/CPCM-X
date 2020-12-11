program COSMO
   use element_dict
   use globals
   use sort
   use initialize_cosmo
   implicit none
   integer :: i,j,z
   real(8), dimension(:), allocatable :: solute_su, solute_area, solute_sv, solute_sv0,solvent_pot,solute_pot
   real(8), dimension(:), allocatable :: solvent_su, solvent_area, solvent_sv, solvent_sv0, solute_svt, solvent_svt
   real(8), dimension(:), allocatable :: sol_pot, solv_pot, solvent_sigma, solute_sigma
   real(8), dimension(:,:), allocatable :: solvent_xyz, solute_xyz
   character(2), dimension(:), allocatable :: solute_ident, solvent_ident
   character(20) :: solvent, solute
   real(8), dimension(10) :: param
   real(8), dimension(5) :: T_a
   real(8) :: id_scr,gas_chem,chem_pot_sol, temp, temp2, T
   logical :: gas
   

   type(DICT_STRUCT), pointer :: r_cav, disp_con
  
   gas=.TRUE.

   Call initialize_param(param,r_cav,disp_con)
   Call getargs(solvent,solute,T)

   Call read_cosmo(trim(solvent)//".cosmo",solvent_ident,solvent_xyz,solvent_su,solvent_area,solvent_pot)
   Call read_cosmo(trim(solute)//".cosmo",solute_ident, solute_xyz, solute_su, solute_area,solute_pot)

   Call average_charge(param(1), solvent_xyz,solvent_su,solvent_area,solvent_sv)
   Call average_charge(param(2), solvent_xyz,solvent_su,solvent_area,solvent_sv0)
   Call ortho_charge(solvent_sv,solvent_sv0,solvent_svt)
   Call average_charge(param(1), solute_xyz, solute_su, solute_area, solute_sv)
   Call average_charge(param(2), solute_xyz, solute_su, solute_area, solute_sv0)
   Call ortho_charge(solute_sv,solute_sv0,solute_svt)
   Call sigma_profile(solvent_sv,solvent_area,solvent_sigma)
   Call sigma_profile(solute_sv,solute_area,solute_sigma)
   Call onedim(solvent_sigma,solute_sigma)
   if (gas) then
      Call calcgas(id_scr,gas_chem,solute_area,solute_sv,solute_su,solute_pot,solute_ident,disp_con,param, T,r_cav)
   end if

   Call compute_solvent(solv_pot,param,solvent_sv,solvent_svt,solvent_area,T,500,0.0001,solvent_sigma)
 !  do i=1,size(solvent_sv)
 !     write(*,*) solvent_sv(i), solv_pot(i)
 !  end do
   Call compute_solute(sol_pot,solv_pot,param,solute_sv,solute_svt,solvent_sv,&
         &solvent_svt,solute_area,solvent_area,T,chem_pot_sol)
  
 !  do i=1,size(solute_sv)
    !  write(*,*) solute_sv(i), solute_svt(i), sol_pot(i)
 !  end do
   
   !   temp=0
   !   do i=1,size(solvent_sv)
   !      temp=temp+E_dd(param(5),param(3),param(4),param(6),solvent_sv(1),solvent_svt(1),solute_sv(j),solute_svt(j))
   !      write(*,*) temp
   !   end do
 write(*,*) gas_chem*4.184
!   temp=0
!   do i=1,size(solvent_pot)
!      do z=1,size(solvent_pot)
!         temp=temp+solvent_area(z)*E_dd(param(5)&
!            &,param(3),param(4),param(6),solvent_sv(i),solvent_svt(i),solvent_sv(z),solvent_svt(z))
!      end do
!      temp2=temp/sum(solvent_area)
!      temp=0
!   end do
!   write(*,*) temp2
deallocate(solute_su,solute_sv,solute_svt,solute_sv0,solvent_su,solvent_sv,&
   &solvent_svt,solvent_sv0,solvent_area,solute_area,solvent_xyz,solute_xyz,&
   &solv_pot,sol_pot)

   
   
   contains

      function distance(xyz1,xyz2)
         use globals
         implicit none
         real(8), dimension(3), intent(in) :: xyz1, xyz2
         real(8) :: distance

         distance=BtoA*(sqrt((xyz1(1)-xyz2(1))**2.0_8+(xyz1(2)-xyz2(2))**2.0_8+(xyz1(3)-xyz2(3))**2.0_8))
         
      end function distance

      subroutine average_charge (r_av, xyz, charges, area,av_charge)
         implicit none
         real(8), dimension(:), allocatable, intent(in) :: charges, area
         real(8), dimension(:,:), allocatable, intent(in) :: xyz
         real(8), intent(in) :: r_av
         real(8), dimension(:), allocatable, intent(out) :: av_charge
         real(8) :: tmpcharge, tmpcounter, tmpdenominator, r_u2, r_av2
         real(8), parameter :: pi = 4*atan(1.0_8)
         integer :: num, i, j

         num = size(charges)
         allocate(av_charge(num))
         r_av2=r_av**2.0_8
         r_u2=0.0_8
         tmpcharge=0.0_8
         tmpcounter=0.0_8
         tmpdenominator=0.0_8
         do i=1,num
            do j=1,num
              ! tmpcounter=tmpcounter+(charges(j)/(area(j)*2.0_8*pi*r_av)*&
               !          &exp(-((distance(xyz(j,:),xyz(i,:))**2.0_8)/(r_av2))))
               r_u2=(area(j)/pi)
              ! tmpdenominator=tmpdenominator+(area(j)/(area(j)*2.0_8*pi*r_av)*&
               !          &exp(-((distance(xyz(j,:),xyz(i,:))**2.0_8)/(r_av2))))
               tmpcounter=tmpcounter+(charges(j)*((r_u2*r_av2)/(r_u2+r_av2))*&
                         &exp(-((distance(xyz(j,:),xyz(i,:))**2.0_8)/(r_u2+r_av2))))
               tmpdenominator=tmpdenominator+(((r_u2*r_av2)/(r_u2+r_av2))*&
                             &exp(-((distance(xyz(j,:),xyz(i,:))**2.0_8)/(r_u2+r_av2))))
               r_u2=0.0_8
            end do
            tmpcharge=tmpcounter/tmpdenominator
            tmpcounter=0.0_8
            tmpdenominator=0.0_8
            av_charge(i)=tmpcharge
         !   av_charge(i)=anint(tmpcharge*1000)/1000
         end do
      end subroutine average_charge

      subroutine ortho_charge (v,v0,vt)
         implicit none
         real(8), dimension(:), allocatable, intent(in) :: v,v0
         real(8), dimension(:), allocatable, intent(out) :: vt

         integer :: i

         allocate(vt(size(v)))

         do i=1,size(v)
            vt(i)=v0(i)-0.816_8*v(i)
         end do

      end subroutine

      subroutine calcgas(id_scr,gas_chem,area,sv,su,pot,ident,disp_con,param, T,r_cav)
         use globals
         use element_dict
         real(8), intent(out) :: id_scr, gas_chem
         real(8), intent(in) :: T
         real(8),dimension(:),allocatable, intent(in) :: area, sv, su, pot
         character(2), dimension(:), allocatable, intent(in) :: ident
         type(DICT_STRUCT), pointer, intent(in) :: disp_con, r_cav
         real(8), dimension(10) :: param
         type(DICT_DATA) :: disp, r_c
         real(8) :: E_gas, E_solv,  dEreal, ediel, edielprime, vdW_gain, thermo, beta, avcorr
         integer :: dummy1, ioerror, i 

         open(1,file="energy")
         read(1,*,iostat=ioerror)
         if (ioerror .NE. 0) then
            write(*,*) "Problem while reading energies (check energy file)."
            error stop
         else
            read(1,*) dummy1,E_gas
            read(1,*) dummy1,E_solv
         end if
         dEreal=(E_gas-E_solv)
         ediel=0
         edielprime=0
         do i=1,size(sv)
            ediel=ediel+(area(i)*pot(i)*su(i))
            edielprime=edielprime+(area(i)*pot(i)*sv(i))
         end do
         avcorr=(edielprime-ediel)/2.0_8*0.8_8
         write(*,*) "E_COSMO+dE: ", (E_solv+avcorr)*autokcal
         write(*,*) "E_gas: ", E_gas*autokcal
         dEreal=dEreal*autokcal
         id_scr=dEreal+avcorr*autokcal
         write(*,*) "E_COSMO-E_gas+dE: ", (E_solv-E_gas+avcorr)*autokcal
         write(*,*) "Ediel: ", ediel/2*autokcal
         write(*,*) "Averaging corr dE: ", avcorr*autokcal


         vdW_gain=0
         do i=1,size(area)
            disp=dict_get_key(disp_con, ident(i))
            vdW_gain=vdW_gain+(area(i)*disp%param)
         end do
         write(*,*) "EvdW: ", vdW_gain 
         write(*,*) "Area: ", sum(area)

         thermo=param(10)*R*jtokcal*T
         write(*,*) "thermostatic correction: ", thermo

         !!! RING CORRECTION IS MISSING ATM
         gas_chem=-id_scr+thermo-vdW_gain!-ring_corr
         write(*,*) gas_chem
         

      end subroutine calcgas

      function E_dd(c_hb,alpha,f_corr,s_hb,sv1,svt1,sv2,svt2)
         implicit none
         real(8), intent(in) :: c_hb, alpha, f_corr,s_hb
         real(8), intent(in) :: sv1, svt1, sv2, svt2
        
         real(8) :: E_dd
         real(8) :: svdo, svac
         real(8) :: E_misfit, E_hb
         
         svac=0
         svdo=0

         if (sv1 .GT. sv2) then
            svac=sv1
            svdo=sv2
         else
            svac=sv2
            svdo=sv1
         end if
         E_hb=0.0_8
         E_misfit=0.0_8
         E_hb=c_hb*max(0.0_8,svac-s_hb)*min(0.0_8,svdo+s_hb)
         E_misfit=(alpha/2)*(sv1+sv2)&
                 &*((sv1+sv2)+f_corr*(svt1+svt2))
      !  E_misfit=(alpha/2)*((sv1+sv2)**2.0_8)
         E_dd=E_hb+E_misfit
      !   write(*,*) E_dd

      end function E_dd

      subroutine iterate_solvent(pot_di,param,sv,svt,area,T,sigma)
         use globals
         implicit none
         real(8), dimension(10), intent(in) :: param
         real(8), dimension(:), allocatable, intent(in) :: sv, svt, area,sigma
         real(8), dimension(:), allocatable, intent(inout) :: pot_di
         real(8), dimension(:), allocatable :: W_v 
         real(8), intent(in) :: T

         real(8), dimension(:), allocatable :: test_di
         real(8) :: temppot, beta
         integer :: i, j

         allocate(W_v(size(sv)))
         W_v(:)=0.0_8
    !     allocate(test_di(size(pot_di)))
      !   test_di(:)=pot_di(:)
         beta=(R*Jtokcal*T)/param(7)
         temppot=0.0_8
         W_v=0.0_8
         !! For mixed solvent, mole fraction needs to be introduced in the following loop
         do j=1,size(pot_di)
            do i=1,size(pot_di)
       !        if (i .NE. j) then
               temppot=temppot+(area(i)*dexp((-E_dd&
                      &(param(5),param(3),param(4),param(6),sv(j),svt(j),sv(i),svt(i))/beta&
                      &+pot_di(i))))
               W_v(j)=W_v(j)+area(i)
        !       end if
            end do
            !exit
            pot_di(j)=-log(temppot/W_v(j))
            temppot=0.0_8
         end do
   !      deallocate(test_di)

      end subroutine iterate_solvent


      subroutine compute_solute(sol_pot,solv_pot,param,sv_sol,svt_sol,sv_solv,svt_solv,area_sol,area_solv,T,chem_pot_sol)
         use globals
         implicit none
         real(8), dimension(10), intent(in) :: param
         real(8), intent(out) :: chem_pot_sol
         real(8), dimension(:), allocatable, intent(in) :: sv_sol, svt_sol,sv_solv,svt_solv,area_solv,area_sol
         real(8), dimension(:), allocatable, intent(inout) :: solv_pot,sol_pot
         real(8), dimension(:), allocatable :: W_v 
         real(8), intent(in) :: T

         real(8) :: temppot, beta,temp2
         integer :: i, j

         allocate(W_v(size(sv_sol)))
         allocate(sol_pot(size(sv_sol)))
         W_v(:)=0.0_8
         beta=0.0832_8!(R*Jtokcal*T)/param(7)
         temppot=0.0_8
         sol_pot(:)=0
         !! For mixed solvent, mole fraction needs to be introduced in the following loop
         do j=1,size(sol_pot)
            do i=1,size(solv_pot)
             !  if (i .NE. j) then
               temppot=temppot+(area_solv(i)*dexp((-E_dd&
                      &(param(5),param(3),param(4),param(6),sv_sol(j),svt_sol(j),sv_solv(i),svt_solv(i))/beta&
                      &+solv_pot(i))))
             !  end if
               W_v(j)=W_v(j)+area_solv(i)
            end do
            sol_pot(j)=-log(sum(area_solv)**(-1)*temppot)
            temppot=0.0_8
         end do
         temppot=0.0_8
         temp2=0
         do i=1,size(sol_pot)
            temppot=temppot+(area_sol(i)*sol_pot(i))
        !    write(*,*) area_sol(i), sol_pot(i), area_sol(i)*sol_pot(i)
         end do

         chem_pot_sol=beta*temppot-(param(8)*R*Jtokcal*T*log(sum(area_solv)))
         write(*,*) chem_pot_sol
         temppot=0
         do i=1,size(solv_pot)
            temppot=temppot+(area_solv(i)*solv_pot(i))
         end do
         write(*,*) beta*temppot
      end subroutine compute_solute

      subroutine compute_solvent(pot_di,param,sv,svt,area,T,max_cycle,conv_crit,sigma_solvent)
         use globals
         implicit none
         real(8), dimension(10), intent(in) :: param
         real(8), dimension(:), allocatable :: sv, svt, area, sigma_solvent
         real(8), dimension(:), allocatable, intent(inout) :: pot_di
         real(8), intent(in) :: T
         real(4), intent(in) :: conv_crit
         integer, intent(in) :: max_cycle
         
         real(8) :: dummy
         integer :: i, j, z
         real(8), dimension(:), allocatable :: saved_potdi,av
         logical :: not_conv
         
         !sv=anint(sv*1000)/1000
         !svt=anint(svt*1000)/1000

         not_conv=.TRUE.
         allocate(pot_di(size(sv)))
         allocate(saved_potdi(size(sv)))
       !  allocate(av(size(sv)))
         pot_di(:)=0.0_8
         saved_potdi(:)=0.0_8
       !  av(:)=0.0_8
         i=0
         do while (not_conv) 
            i=i+1
        !    write(*,*) pot_di
      !      do z=1,size(pot_di)
      !         av(z)=(saved_potdi(z)+pot_di(z))/2.0_8
      !      end do
            saved_potdi(:)=pot_di(:)
!            write(*,*) sum(pot_di)
            Call iterate_solvent(pot_di,param,sv,svt,area,T,sigma_solvent)
       !     pot_di(:)=av(:)
            not_conv=.FALSE.
            do j=1,size(pot_di)
               if (abs(saved_potdi(j)-pot_di(j)) .LE. (conv_crit/autokcal)) then
                  cycle
               else
                  not_conv=.TRUE.
                  exit
               end if
            end do
            if (i .GE. max_cycle) then
               exit
            end if
         end do
       !  write(*,*) pot_di(:)
       !  Call reorder(sv,pot_di,area)
         if (not_conv) then
            write(*,*) "Error, chemical potential could not be converged"
            error stop
         else
            write(*,*) "Done! Chemical potential converged after Cycle ",i
         end if


      end subroutine compute_solvent

      subroutine sigma_profile(sv,area,sigma)

         real(8), dimension(:), allocatable,intent(in) :: sv,area

         real(8), dimension(:), allocatable,intent(out) :: sigma

         integer :: sigma_min, sigma_max, i, j,tmp

         real(8) :: punit

         real(8), parameter :: sig_width=0.025_8
         integer, parameter :: n_sig=50

         real(8) :: profile(0:n_sig), chdval(0:n_sig), temp

         punit=2.0_8*sig_width/n_sig

         do i=0,n_sig
            profile(i) = 0.0_8
            chdval(i) = -sig_width+punit*i
         end do
         do i= 1, size(sv)
            temp = sv(i)
           
            tmp = int((temp-chdval(0))/punit)
           
            if (tmp<0) tmp=0
            if (tmp>n_sig-1) tmp=n_sig-1
            profile(tmp) = profile(tmp)+area(i)*(chdval(tmp+1)-temp)/punit
            profile(tmp+1) = profile(tmp+1)+area(i)*(temp-chdval(tmp))/punit
         end do
         open(unit=2,file="sigma_profile.txt",action="write",status="replace")
         
         do i=0,size(profile)-1
            write(2,*) chdval(i),";", profile(i)/sum(area)
         end do
         close(2)

         allocate(sigma(0:size(profile)))
         sigma(:)=profile(:)

      end subroutine

include "onedim.f90"
end program COSMO

