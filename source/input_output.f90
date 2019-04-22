module input_output
    use netcdf
    use mod_atparam

    implicit none

    private
    public output, load_boundary_file

    interface load_boundary_file
        module procedure load_boundary_file_2d
        module procedure load_boundary_file_one_month_from_year
        module procedure load_boundary_file_one_month_from_long
    end interface

contains
    function load_boundary_file_2d(file_name, field_name) result(field)
        character(len=*), intent(in) :: file_name, field_name

        integer :: i, ncid, varid
        real(4), dimension(ix,il) :: raw_input
        real, dimension(ix,il) :: field

        write (*,'(A,A,A,A)') 'Reading ', field_name, ' from ', file_name

        ! Open boundary file, read variable and then close
        call check(nf90_open(file_name, nf90_nowrite, ncid))
        call check(nf90_inq_varid(ncid, field_name, varid))
        call check(nf90_get_var(ncid, varid, raw_input, start = (/ 1, 1 /), count =  (/ ix, il /)))
        call check(nf90_close(ncid))
        field = raw_input(:,il:1:-1)

        ! Fix undefined values
        where (field <= -999) field = 0.0
    end

    function load_boundary_file_one_month_from_year(file_name, field_name, month) result(field)
        character(len=*), intent(in) :: file_name, field_name
        integer, intent(in) :: month

        integer :: ncid, varid
        real(4), dimension(ix,il,12) :: raw_input
        real, dimension(ix,il) :: field

        write (*,'(A,A,A,I0.2,A,A)') 'Reading ', field_name, ' (month ', month, ') from ', file_name

        ! Open boundary file, read variable and then close
        call check(nf90_open(file_name, nf90_nowrite, ncid))
        call check(nf90_inq_varid(ncid, field_name, varid))
        call check(nf90_get_var(ncid, varid, raw_input))
        call check(nf90_close(ncid))
        field = raw_input(:,il:1:-1,month)

        ! Fix undefined values
        where (field <= -999) field = 0.0
    end

    function load_boundary_file_one_month_from_long(file_name, field_name, month, length) &
        & result(field)
        character(len=*), intent(in) :: file_name, field_name
        integer, intent(in) :: month, length

        integer :: ncid, varid
        real(4), dimension(ix,il,length) :: raw_input
        real, dimension(ix,il) :: field

        write (*,'(A,A,A,I0.2,A,A)') 'Reading ', field_name, ' (month ', month, ') from ', file_name

        ! Open boundary file, read variable and then close
        call check(nf90_open(file_name, nf90_nowrite, ncid))
        call check(nf90_inq_varid(ncid, field_name, varid))
        call check(nf90_get_var(ncid, varid, raw_input))
        call check(nf90_close(ncid))
        field = raw_input(:,il:1:-1,month)

        ! Fix undefined values
        where (field <= -999) field = 0.0
    end

    subroutine output(timestep)
        use mod_dyncon1, only: radang, grav
        use physical_constants, only: p0, sig
        use date, only: model_datetime, start_datetime
        use mod_tsteps, only: nsteps
        use prognostics, only: vor, div, t, ps, tr, phi
        use spectral, only: spec_to_grid

        integer, intent(in) :: timestep
        complex, dimension(mx,nx) :: ucos, vcos
        real, dimension(ix,il,kx) :: u_grid, v_grid, t_grid, q_grid, phi_grid
        real, dimension(ix,il) :: ps_grid
        real(4), dimension(ix,il,kx) :: u_out, v_out, t_out, q_out, phi_out
        real(4), dimension(ix,il) :: ps_out
        character(len=15) :: file_name = 'yyyymmddhhmm.nc'
        character(len=32) :: time_template = 'hours since yyyy-mm-dd hh:mm:0.0'
        integer :: k, ncid
        integer :: timedim, latdim, londim, levdim
        integer :: timevar, latvar, lonvar, levvar, uvar, vvar, tvar, qvar, phivar, psvar

        ! Construct file_name
        write (file_name(1:4),'(i4.4)') model_datetime%year
        write (file_name(5:6),'(i2.2)') model_datetime%month
        write (file_name(7:8),'(i2.2)') model_datetime%day
        write (file_name(9:10),'(i2.2)') model_datetime%hour
        write (file_name(11:12),'(i2.2)') model_datetime%minute

        ! Construct time string
        write (time_template(13:16),'(i4.4)') start_datetime%year
        write (time_template(18:19),'(i2.2)') start_datetime%month
        write (time_template(21:22),'(i2.2)') start_datetime%day
        write (time_template(24:25),'(i2.2)') start_datetime%hour
        write (time_template(27:28),'(i2.2)') start_datetime%minute

        ! Create NetCDF output file
        call check(nf90_create(file_name, nf90_clobber, ncid))

        ! Define time
        call check(nf90_def_dim(ncid, "time", nf90_unlimited, timedim))
        call check(nf90_def_var(ncid, "time", nf90_real4, timedim, timevar))
        call check(nf90_put_att(ncid, timevar, "units", time_template))

        ! Define space
        call check(nf90_def_dim(ncid, "lon", ix, londim))
        call check(nf90_def_dim(ncid, "lat", il, latdim))
        call check(nf90_def_dim(ncid, "lev", kx, levdim))
        call check(nf90_def_var(ncid, "lon", nf90_real4, londim, lonvar))
        call check(nf90_put_att(ncid, lonvar, "long_name", "longitude"))
        call check(nf90_def_var(ncid, "lat", nf90_real4, latdim, latvar))
        call check(nf90_put_att(ncid, latvar, "long_name", "latitude"))
        call check(nf90_def_var(ncid, "lev", nf90_real4, levdim, levvar))
        call check(nf90_put_att(ncid, levvar, "long_name", "atmosphere_sigma_coordinate"))

        ! Define prognostic fields
        call check(nf90_def_var(ncid, "u", nf90_real4, (/ londim, latdim, levdim, timedim /), uvar))
        call check(nf90_put_att(ncid, uvar, "long_name", "eastward_wind"))
        call check(nf90_put_att(ncid, uvar, "units", "m/s"))
        call check(nf90_def_var(ncid, "v", nf90_real4, (/ londim, latdim, levdim, timedim /), vvar))
        call check(nf90_put_att(ncid, vvar, "long_name", "northward_wind"))
        call check(nf90_put_att(ncid, vvar, "units", "m/s"))
        call check(nf90_def_var(ncid, "t", nf90_real4, (/ londim, latdim, levdim, timedim /), tvar))
        call check(nf90_put_att(ncid, tvar, "long_name", "air_temperature"))
        call check(nf90_put_att(ncid, tvar, "units", "K"))
        call check(nf90_def_var(ncid, "q", nf90_real4, (/ londim, latdim, levdim, timedim /), qvar))
        call check(nf90_put_att(ncid, qvar, "long_name", "specific_humidity"))
        call check(nf90_put_att(ncid, qvar, "units", "1"))

        call check(nf90_def_var(ncid, "phi", nf90_real4, (/ londim, latdim, levdim, timedim /), &
            & phivar))
        call check(nf90_put_att(ncid, phivar, "long_name", "geopotential_height"))
        call check(nf90_put_att(ncid, phivar, "units", "m"))
        call check(nf90_def_var(ncid, "ps", nf90_real4, (/ londim, latdim, timedim /), psvar))
        call check(nf90_put_att(ncid, psvar, "long_name", "surface_air_pressure"))
        call check(nf90_put_att(ncid, psvar, "units", "Pa"))

        call check(nf90_enddef(ncid))

        ! Write dimensions to file
        call check(nf90_put_var(ncid, timevar, timestep*24.0/real(nsteps,4),               (/ 1 /)))
        call check(nf90_put_var(ncid, lonvar, (/ (3.75*k, k = 0, ix-1) /),                 (/ 1 /)))
        call check(nf90_put_var(ncid, latvar, (/ (radang(k)*90.0/asin(1.0), k = 1, il) /), (/ 1 /)))
        call check(nf90_put_var(ncid, levvar, (/ (sig(k), k = 1, 8) /),                    (/ 1 /)))

        ! Convert prognostic fields from spectral space to grid point space
        do k = 1, kx
           call uvspec(vor(:,:,k,1), div(:,:,k,1), ucos, vcos)
           u_grid(:,:,k)   = spec_to_grid(ucos, 2)
           v_grid(:,:,k)   = spec_to_grid(vcos, 2)
           t_grid(:,:,k)   = spec_to_grid(t(:,:,k,1), 1)
           q_grid(:,:,k)   = spec_to_grid(tr(:,:,k,1,1), 1)
           phi_grid(:,:,k) = spec_to_grid(phi(:,:,k), 1)
        end do
        ps_grid = spec_to_grid(ps(:,:,1), 1)

        ! Output date
        print '(A,I4.4,A,I2.2,A,I2.2,A,I2.2,A,I2.2)',&
            & 'Write gridded dataset for year/month/date/hour/minute: ', &
            & model_datetime%year,'/',model_datetime%month,'/',model_datetime%day,'/', &
            & model_datetime%hour,'/',model_datetime%minute

        ! Preprocess output variables
        u_out = u_grid
        v_out = v_grid
        t_out = t_grid
        q_out = q_grid*1.0d-3 ! kg/kg
        phi_out = phi_grid/grav   ! m
        ps_out = p0*exp(ps_grid)! Pa

        ! Write prognostic variables to file
        call check(nf90_put_var(ncid, uvar, u_out, (/ 1, 1, 1, 1 /)))
        call check(nf90_put_var(ncid, vvar, v_out, (/ 1, 1, 1, 1 /)))
        call check(nf90_put_var(ncid, tvar, t_out, (/ 1, 1, 1, 1 /)))
        call check(nf90_put_var(ncid, qvar, q_out, (/ 1, 1, 1, 1 /)))
        call check(nf90_put_var(ncid, phivar, phi_out, (/ 1, 1, 1, 1 /)))
        call check(nf90_put_var(ncid, psvar, ps_out, (/ 1, 1, 1 /)))

        call check(nf90_close(ncid))
    end subroutine

    ! Handles any errors from the NetCDF API
    subroutine check(ierr)
        integer, intent(in) :: ierr

        if (ierr /= nf90_noerr) then
            print *, trim(adjustl(nf90_strerror(ierr)))
            stop
        end if
    end subroutine
end module
