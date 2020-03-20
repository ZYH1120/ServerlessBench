/* -*-mode:c++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

#include "backend_redis.hh"
#include "time.h"
#include <iostream>

using namespace std;
using namespace storage;

void RedisStorageBackend::put( const std::vector<PutRequest> & requests,
                               const PutCallback & success_callback )
{
  struct timespec start, finish;

  clock_gettime(CLOCK_MONOTONIC, &start);

  client_.upload_files( requests, success_callback );

  clock_gettime(CLOCK_MONOTONIC, &finish);
  
  double elapsed = (finish.tv_sec - start.tv_sec ) * 1000;
  elapsed += (finish.tv_nsec - start.tv_nsec) / 1000000.0;
  commTime += elapsed;
  cout << "start time: " << start.tv_sec << "." << start.tv_nsec << "s, ";
  cout << "finish time: " << finish.tv_sec << "." << finish.tv_nsec << "s, ";
  cout << "elapse: " << elapsed << "ms" << endl;
  cout << "commTime: " << commTime << endl;

}

void RedisStorageBackend::get( const std::vector<GetRequest> & requests,
                               const GetCallback & success_callback )
{
  struct timespec start, finish;

  clock_gettime(CLOCK_MONOTONIC, &start);

  client_.download_files( requests, success_callback );

  clock_gettime(CLOCK_MONOTONIC, &finish);
  
  double elapsed = (finish.tv_sec - start.tv_sec ) * 1000;
  elapsed += (finish.tv_nsec - start.tv_nsec) / 1000000.0;
  commTime += elapsed;

  cout << "start time: " << start.tv_sec << "." << start.tv_nsec << "s, ";
  cout << "finish time: " << finish.tv_sec << "." << finish.tv_nsec << "s, ";
  cout << "elapse: " << elapsed << "ms" << endl;
  cout << "commTime: " << commTime << endl;
}
